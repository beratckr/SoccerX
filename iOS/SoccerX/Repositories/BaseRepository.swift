import Foundation
import FirebaseFirestore
import Combine

// Base protocol for all repositories
protocol BaseRepositoryProtocol {
    associatedtype T: Codable & Identifiable
    
    func create(_ item: T) -> AnyPublisher<T, RepositoryError>
    func read(id: String) -> AnyPublisher<T?, RepositoryError>
    func update(_ item: T) -> AnyPublisher<T, RepositoryError>
    func delete(id: String) -> AnyPublisher<Void, RepositoryError>
    func observeChanges(id: String) -> AnyPublisher<T?, RepositoryError>
}

// Repository errors
enum RepositoryError: Error, LocalizedError {
    case networkError(Error)
    case permissionDenied
    case documentNotFound
    case invalidData
    case encodingError
    case decodingError
    case transactionFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied"
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        case .encodingError:
            return "Failed to encode data"
        case .decodingError:
            return "Failed to decode data"
        case .transactionFailed:
            return "Transaction failed"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// Base repository implementation
class BaseRepository<T: Codable & Identifiable> {
    let db: Firestore
    let collectionPath: String
    
    init(collectionPath: String) {
        self.db = Firestore.firestore()
        self.collectionPath = collectionPath
        
        // Configure offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    var collection: CollectionReference {
        db.collection(collectionPath)
    }
    
    // MARK: - CRUD Operations
    
    func create(_ item: T) -> AnyPublisher<T, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "BaseRepository", code: -1))))
                return
            }
            
            do {
                let data = try Firestore.Encoder().encode(item)
                
                if let documentId = item.id as? String {
                    // Use provided ID
                    self.collection.document(documentId).setData(data) { error in
                        if let error = error {
                            promise(.failure(self.mapError(error)))
                        } else {
                            promise(.success(item))
                        }
                    }
                } else {
                    // Generate new ID
                    let ref = self.collection.addDocument(data: data) { error in
                        if let error = error {
                            promise(.failure(self.mapError(error)))
                        } else {
                            promise(.success(item))
                        }
                    }
                    
                    // Update item ID if it's a mutable property
                    // This would need to be handled in specific repositories
                }
            } catch {
                promise(.failure(.encodingError))
            }
        }
        .retry(2)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func read(id: String) -> AnyPublisher<T?, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "BaseRepository", code: -1))))
                return
            }
            
            self.collection.document(id).getDocument { snapshot, error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    promise(.success(nil))
                    return
                }
                
                do {
                    let item = try snapshot.data(as: T.self)
                    promise(.success(item))
                } catch {
                    promise(.failure(.decodingError))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func update(_ item: T) -> AnyPublisher<T, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self,
                  let documentId = item.id as? String else {
                promise(.failure(.invalidData))
                return
            }
            
            do {
                let data = try Firestore.Encoder().encode(item)
                
                self.collection.document(documentId).setData(data, merge: true) { error in
                    if let error = error {
                        promise(.failure(self.mapError(error)))
                    } else {
                        promise(.success(item))
                    }
                }
            } catch {
                promise(.failure(.encodingError))
            }
        }
        .retry(1)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func delete(id: String) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "BaseRepository", code: -1))))
                return
            }
            
            self.collection.document(id).delete { error in
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
    
    // MARK: - Real-time Operations
    
    func observeChanges(id: String) -> AnyPublisher<T?, RepositoryError> {
        let subject = PassthroughSubject<T?, RepositoryError>()
        
        let listener = collection.document(id).addSnapshotListener { snapshot, error in
            if let error = error {
                subject.send(completion: .failure(self.mapError(error)))
                return
            }
            
            guard let snapshot = snapshot else {
                subject.send(nil)
                return
            }
            
            if snapshot.exists {
                do {
                    let item = try snapshot.data(as: T.self)
                    subject.send(item)
                } catch {
                    subject.send(completion: .failure(.decodingError))
                }
            } else {
                subject.send(nil)
            }
        }
        
        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func observeCollection(query: Query? = nil) -> AnyPublisher<[T], RepositoryError> {
        let subject = PassthroughSubject<[T], RepositoryError>()
        let targetQuery = query ?? collection
        
        let listener = targetQuery.addSnapshotListener { snapshot, error in
            if let error = error {
                subject.send(completion: .failure(self.mapError(error)))
                return
            }
            
            guard let snapshot = snapshot else {
                subject.send([])
                return
            }
            
            do {
                let items = try snapshot.documents.compactMap { document in
                    try document.data(as: T.self)
                }
                subject.send(items)
            } catch {
                subject.send(completion: .failure(.decodingError))
            }
        }
        
        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Query Operations
    
    func fetch(query: Query) -> AnyPublisher<[T], RepositoryError> {
        Future { promise in
            query.getDocuments { snapshot, error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                    return
                }
                
                guard let snapshot = snapshot else {
                    promise(.success([]))
                    return
                }
                
                do {
                    let items = try snapshot.documents.compactMap { document in
                        try document.data(as: T.self)
                    }
                    promise(.success(items))
                } catch {
                    promise(.failure(.decodingError))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Batch Operations
    
    func batchWrite(operations: [(T, BatchOperationType)]) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "BaseRepository", code: -1))))
                return
            }
            
            let batch = self.db.batch()
            
            do {
                for (item, operation) in operations {
                    guard let documentId = item.id as? String else {
                        promise(.failure(.invalidData))
                        return
                    }
                    
                    let documentRef = self.collection.document(documentId)
                    let data = try Firestore.Encoder().encode(item)
                    
                    switch operation {
                    case .create:
                        batch.setData(data, forDocument: documentRef)
                    case .update:
                        batch.setData(data, forDocument: documentRef, merge: true)
                    case .delete:
                        batch.deleteDocument(documentRef)
                    }
                }
                
                batch.commit { error in
                    if let error = error {
                        promise(.failure(self.mapError(error)))
                    } else {
                        promise(.success(()))
                    }
                }
            } catch {
                promise(.failure(.encodingError))
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

enum BatchOperationType {
    case create
    case update
    case delete
}