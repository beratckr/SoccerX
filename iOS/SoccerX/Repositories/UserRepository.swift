import Foundation
import FirebaseFirestore
import Combine

class UserRepository: BaseRepository<User> {
    
    init() {
        super.init(collectionPath: "users")
    }
    
    // MARK: - User-specific operations
    
    func getCurrentUser(uid: String) -> AnyPublisher<User?, RepositoryError> {
        return read(id: uid)
    }
    
    func updateUserStats(uid: String, stats: UserStats) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "UserRepository", code: -1))))
                return
            }
            
            let data = stats.toDictionary()
            self.collection.document(uid).updateData(["stats": data]) { error in
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
    
    func addUserToGroup(uid: String, groupId: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "UserRepository", code: -1))))
                return
            }
            
            self.collection.document(uid).updateData([
                "groupIds": FieldValue.arrayUnion([groupId])
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
    
    func removeUserFromGroup(uid: String, groupId: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "UserRepository", code: -1))))
                return
            }
            
            self.collection.document(uid).updateData([
                "groupIds": FieldValue.arrayRemove([groupId])
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
    
    func searchUsers(by displayName: String, limit: Int = 20) -> AnyPublisher<[User], RepositoryError> {
        let query = collection
            .whereField("displayName", isGreaterThanOrEqualTo: displayName)
            .whereField("displayName", isLessThan: displayName + "\u{f8ff}")
            .limit(to: limit)
        
        return fetch(query: query)
    }
    
    func getUsersByIds(_ userIds: [String]) -> AnyPublisher<[User], RepositoryError> {
        // Firestore has a limit of 10 items for 'in' queries
        let chunkedIds = userIds.chunked(into: 10)
        
        let publishers = chunkedIds.map { chunk in
            let query = collection.whereField("uid", in: chunk)
            return fetch(query: query)
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { arrays in
                arrays.flatMap { $0 }
            }
            .eraseToAnyPublisher()
    }
    
    func updateUserPremiumStatus(uid: String, isPremium: Bool) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "UserRepository", code: -1))))
                return
            }
            
            self.collection.document(uid).updateData([
                "isPremium": isPremium,
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

// MARK: - Array Extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}