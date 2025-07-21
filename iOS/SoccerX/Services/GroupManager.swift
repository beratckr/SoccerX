import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

class GroupManager: ObservableObject {
    static let shared = GroupManager()
    
    private let groupRepository = GroupRepository()
    private let userRepository = UserRepository()
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var userGroups: [Group] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private init() {
        observeUserGroups()
    }
    
    // MARK: - Group Creation
    
    func createGroup(name: String, description: String?, isPublic: Bool) -> AnyPublisher<Group, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: GroupError.notAuthorized)
                .eraseToAnyPublisher()
        }
        
        let inviteCode = generateInviteCode()
        
        var group = Group(name: name, description: description, creatorId: currentUser.uid)
        group.isPublic = isPublic
        group.inviteCode = inviteCode
        group.maxMembers = 10 // Default for free users
        group.isPremium = false
        
        return groupRepository.create(group)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.observeUserGroups()
            })
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Group Management
    
    func joinGroup(by inviteCode: String) -> AnyPublisher<Group, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: GroupError.notAuthorized)
                .eraseToAnyPublisher()
        }
        
        return groupRepository.findGroupByInviteCode(inviteCode)
            .mapError { $0 as Error }
            .flatMap { group -> AnyPublisher<Group, Error> in
                guard let group = group else {
                    return Fail(error: GroupError.invalidInviteCode)
                        .eraseToAnyPublisher()
                }
                
                guard let groupId = group.id else {
                    return Fail(error: GroupError.invalidGroupData)
                        .eraseToAnyPublisher()
                }
                
                return self.groupRepository.joinGroup(groupId: groupId, userId: currentUser.uid)
                    .map { _ in group }
                    .mapError { $0 as Error }
                    .eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.observeUserGroups()
            })
            .eraseToAnyPublisher()
    }
    
    func leaveGroup(_ groupId: String) -> AnyPublisher<Void, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: GroupError.notAuthorized)
                .eraseToAnyPublisher()
        }
        
        return groupRepository.leaveGroup(groupId: groupId, userId: currentUser.uid)
            .mapError { $0 as Error }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.observeUserGroups()
            })
            .eraseToAnyPublisher()
    }
    
    func updateGroup(_ groupId: String, name: String? = nil, description: String? = nil, isPublic: Bool? = nil) -> AnyPublisher<Void, Error> {
        return groupRepository.read(id: groupId)
            .mapError { $0 as Error }
            .flatMap { group -> AnyPublisher<Void, Error> in
                guard var group = group else {
                    return Fail(error: RepositoryError.documentNotFound as Error)
                        .eraseToAnyPublisher()
                }
                
                if let name = name {
                    group.name = name
                }
                if let description = description {
                    group.description = description
                }
                if let isPublic = isPublic {
                    group.isPublic = isPublic
                }
                
                return self.groupRepository.update(group)
                    .mapError { $0 as Error }
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func deleteGroup(_ groupId: String) -> AnyPublisher<Void, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: GroupError.notAuthorized)
                .eraseToAnyPublisher()
        }
        
        return groupRepository.read(id: groupId)
            .mapError { $0 as Error }
            .flatMap { group -> AnyPublisher<Void, Error> in
                guard let group = group else {
                    return Fail(error: RepositoryError.documentNotFound as Error)
                        .eraseToAnyPublisher()
                }
                
                // Only creator can delete group
                guard group.creatorId == currentUser.uid else {
                    return Fail(error: GroupError.notAuthorized as Error)
                        .eraseToAnyPublisher()
                }
                
                return self.groupRepository.delete(id: groupId)
                    .mapError { $0 as Error }
                    .eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.observeUserGroups()
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Member Management
    
    func removeMember(from groupId: String, userId: String) -> AnyPublisher<Void, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: GroupError.notAuthorized)
                .eraseToAnyPublisher()
        }
        
        return groupRepository.kickMember(groupId: groupId, userId: userId, currentUserId: currentUser.uid)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func generateNewInviteCode(for groupId: String) -> AnyPublisher<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: GroupError.notAuthorized)
                .eraseToAnyPublisher()
        }
        
        return groupRepository.read(id: groupId)
            .mapError { $0 as Error }
            .flatMap { group -> AnyPublisher<String, Error> in
                guard var group = group else {
                    return Fail(error: RepositoryError.documentNotFound as Error)
                        .eraseToAnyPublisher()
                }
                
                // Only creator can regenerate invite code
                guard group.creatorId == currentUser.uid else {
                    return Fail(error: GroupError.notAuthorized as Error)
                        .eraseToAnyPublisher()
                }
                
                let newCode = self.generateInviteCode()
                group.inviteCode = newCode
                
                return self.groupRepository.update(group)
                    .map { _ in newCode }
                    .mapError { $0 as Error }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Weekly Challenge Management
    
    func setWeeklyChallenge(for groupId: String, challenge: WeeklyChallenge) -> AnyPublisher<Void, Error> {
        return groupRepository.setWeeklyChallenge(groupId: groupId, challenge: challenge)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func removeWeeklyChallenge(from groupId: String) -> AnyPublisher<Void, Error> {
        return groupRepository.removeWeeklyChallenge(groupId: groupId)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Search and Discovery
    
    func searchPublicGroups(query: String) -> AnyPublisher<[Group], Error> {
        if query.isEmpty {
            return groupRepository.getPublicGroups(limit: 20)
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        } else {
            return groupRepository.searchGroups(by: query, limit: 20)
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Private Methods
    
    private func observeUserGroups() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        groupRepository.observeUserGroups(uid: currentUser.uid)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] groups in
                    self?.userGroups = groups
                }
            )
            .store(in: &cancellables)
    }
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Group Stats
    
    func getGroupStatistics(for groupId: String) -> AnyPublisher<GroupStatistics, Error> {
        groupRepository.read(id: groupId)
            .mapError { $0 as Error }
            .flatMap { group -> AnyPublisher<GroupStatistics, Error> in
                guard let group = group else {
                    return Fail(error: RepositoryError.documentNotFound as Error)
                        .eraseToAnyPublisher()
                }
                
                // Get all members' games for the current week
                let calendar = Calendar.current
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                
                let memberGamePublishers: [AnyPublisher<MemberStats, Never>] = group.memberIds.map { memberId in
                    GameRepository().getUserGamesInDateRange(
                        uid: memberId,
                        startDate: startOfWeek,
                        endDate: Date()
                    )
                    .mapError { $0 as Error }
                    .map { games in
                        MemberStats(
                            weeklyGames: games.count,
                            weeklyDistance: games.reduce(0) { $0 + $1.distance },
                            weeklyMVPAverage: games.compactMap { $0.mvpScore }.reduce(0, +) / Double(max(games.count, 1)),
                            allTimeGames: 0, // Would need to fetch all-time stats
                            allTimeDistance: 0.0,
                            currentStreak: 0
                        )
                    }
                    .replaceError(with: MemberStats(weeklyGames: 0, weeklyDistance: 0, weeklyMVPAverage: 0, allTimeGames: 0, allTimeDistance: 0, currentStreak: 0))
                    .eraseToAnyPublisher()
                }
                
                return Publishers.MergeMany(memberGamePublishers)
                    .collect()
                    .map { (memberStats: [MemberStats]) -> GroupStatistics in
                        GroupStatistics(
                            groupId: groupId,
                            totalMembers: group.memberIds.count,
                            weeklyActiveMembers: memberStats.filter { $0.weeklyGames > 0 }.count,
                            totalWeeklyGames: memberStats.reduce(0) { $0 + $1.weeklyGames },
                            totalWeeklyDistance: memberStats.reduce(0) { $0 + $1.weeklyDistance },
                            memberStats: memberStats.sorted { $0.weeklyDistance > $1.weeklyDistance }
                        )
                    }
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

struct GroupStatistics {
    let groupId: String
    let totalMembers: Int
    let weeklyActiveMembers: Int
    let totalWeeklyGames: Int
    let totalWeeklyDistance: Double
    let memberStats: [MemberStats]
}

// Note: MemberStats is defined in Models/Group.swift