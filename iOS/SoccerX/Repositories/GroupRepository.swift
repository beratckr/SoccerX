import Foundation
import FirebaseFirestore
import Combine

class GroupRepository: BaseRepository<Group> {
    
    init() {
        super.init(collectionPath: "groups")
    }
    
    // MARK: - Group-specific operations
    
    func getUserGroups(uid: String) -> AnyPublisher<[Group], RepositoryError> {
        let query = collection
            .whereField("memberIds", arrayContains: uid)
            .order(by: "updatedAt", descending: true)
        
        return fetch(query: query)
    }
    
    func observeUserGroups(uid: String) -> AnyPublisher<[Group], RepositoryError> {
        let query = collection
            .whereField("memberIds", arrayContains: uid)
            .order(by: "updatedAt", descending: true)
        
        return observeCollection(query: query)
    }
    
    func getPublicGroups(limit: Int = 20) -> AnyPublisher<[Group], RepositoryError> {
        let query = collection
            .whereField("isPublic", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        return fetch(query: query)
    }
    
    func searchGroups(by name: String, limit: Int = 20) -> AnyPublisher<[Group], RepositoryError> {
        let query = collection
            .whereField("isPublic", isEqualTo: true)
            .whereField("name", isGreaterThanOrEqualTo: name)
            .whereField("name", isLessThan: name + "\u{f8ff}")
            .limit(to: limit)
        
        return fetch(query: query)
    }
    
    func findGroupByInviteCode(_ inviteCode: String) -> AnyPublisher<Group?, RepositoryError> {
        let query = collection
            .whereField("inviteCode", isEqualTo: inviteCode)
            .limit(to: 1)
        
        return fetch(query: query)
            .map { groups in groups.first }
            .eraseToAnyPublisher()
    }
    
    func joinGroup(groupId: String, userId: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GroupRepository", code: -1))))
                return
            }
            
            // Use transaction to ensure atomic operation
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                let groupRef = self.collection.document(groupId)
                
                do {
                    let groupSnapshot = try transaction.getDocument(groupRef)
                    guard let groupData = groupSnapshot.data(),
                          let memberIds = groupData["memberIds"] as? [String],
                          let maxMembers = groupData["maxMembers"] as? Int else {
                        throw RepositoryError.invalidData
                    }
                    
                    // Check if group is full
                    if memberIds.count >= maxMembers {
                        throw GroupError.groupFull
                    }
                    
                    // Check if user is already a member
                    if memberIds.contains(userId) {
                        throw GroupError.alreadyMember
                    }
                    
                    // Add user to group
                    transaction.updateData([
                        "memberIds": FieldValue.arrayUnion([userId]),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: groupRef)
                    
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { (result, error) in
                if let error = error {
                    if let groupError = error as? GroupError {
                        promise(.failure(.unknown(groupError)))
                    } else {
                        promise(.failure(self.mapError(error)))
                    }
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func leaveGroup(groupId: String, userId: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GroupRepository", code: -1))))
                return
            }
            
            self.collection.document(groupId).updateData([
                "memberIds": FieldValue.arrayRemove([userId]),
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func updateGroupSettings(groupId: String, settings: GroupSettings) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GroupRepository", code: -1))))
                return
            }
            
            self.collection.document(groupId).updateData([
                "settings": settings.toDictionary(),
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func setWeeklyChallenge(groupId: String, challenge: WeeklyChallenge) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GroupRepository", code: -1))))
                return
            }
            
            self.collection.document(groupId).updateData([
                "weeklyChallenge": challenge.toDictionary(),
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func removeWeeklyChallenge(groupId: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GroupRepository", code: -1))))
                return
            }
            
            self.collection.document(groupId).updateData([
                "weeklyChallenge": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func getGroupMembers(groupId: String) -> AnyPublisher<[User], RepositoryError> {
        read(id: groupId)
            .compactMap { $0?.memberIds }
            .flatMap { memberIds in
                UserRepository().getUsersByIds(memberIds)
            }
            .eraseToAnyPublisher()
    }
    
    func observeGroupMembers(groupId: String) -> AnyPublisher<[User], RepositoryError> {
        observeChanges(id: groupId)
            .compactMap { $0?.memberIds }
            .flatMap { memberIds in
                UserRepository().getUsersByIds(memberIds)
            }
            .eraseToAnyPublisher()
    }
    
    func kickMember(groupId: String, userId: String, currentUserId: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GroupRepository", code: -1))))
                return
            }
            
            // Use transaction to ensure atomic operation and check permissions
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                let groupRef = self.collection.document(groupId)
                
                do {
                    let groupSnapshot = try transaction.getDocument(groupRef)
                    guard let groupData = groupSnapshot.data(),
                          let creatorId = groupData["creatorId"] as? String else {
                        throw RepositoryError.invalidData
                    }
                    
                    // Check if current user is the creator
                    if creatorId != currentUserId {
                        throw GroupError.notAuthorized
                    }
                    
                    // Can't kick the creator
                    if userId == creatorId {
                        throw GroupError.cannotKickCreator
                    }
                    
                    // Remove user from group
                    transaction.updateData([
                        "memberIds": FieldValue.arrayRemove([userId]),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: groupRef)
                    
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { (result, error) in
                if let error = error {
                    if let groupError = error as? GroupError {
                        promise(.failure(.unknown(groupError)))
                    } else {
                        promise(.failure(self.mapError(error)))
                    }
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mapError(_ error: Error) -> RepositoryError {
        if let firestoreError = error as NSError? {
            switch firestoreError.code {
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.notFound.rawValue:
                return .documentNotFound
            case FirestoreErrorCode.unavailable.rawValue,
                 FirestoreErrorCode.deadlineExceeded.rawValue:
                return .networkError(error)
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
}

// MARK: - Group-specific Errors

enum GroupError: Error, LocalizedError {
    case groupFull
    case alreadyMember
    case notAuthorized
    case cannotKickCreator
    case invalidInviteCode
    case invalidGroupData
    
    var errorDescription: String? {
        switch self {
        case .groupFull:
            return "Group is full"
        case .alreadyMember:
            return "User is already a member"
        case .notAuthorized:
            return "Not authorized to perform this action"
        case .cannotKickCreator:
            return "Cannot kick the group creator"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .invalidGroupData:
            return "Invalid group data"
        }
    }
}