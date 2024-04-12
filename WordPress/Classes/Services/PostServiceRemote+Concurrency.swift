import Foundation
import WordPressKit

extension PostServiceRemote {
    func post(withID postID: NSNumber) async throws -> RemotePost {
        try await withCheckedThrowingContinuation { continuation in
            getPostWithID(postID, success: {
                guard let post = $0 else {
                    return continuation.resume(throwing: URLError(.unknown))
                }
                continuation.resume(returning: post)
            }, failure: {
                continuation.resume(throwing: $0 ?? URLError(.unknown))
            })
        }
    }

    func trashPost(_ post: RemotePost) async throws -> RemotePost {
        try await withCheckedThrowingContinuation { continuation in
            trashPost(post) {
                guard let post = $0 else {
                    return continuation.resume(throwing: URLError(.unknown))
                }
                continuation.resume(returning: post)
            } failure: {
                continuation.resume(throwing: $0 ?? URLError(.unknown))
            }
        }
    }
}

extension PostServiceRemoteREST {
    struct AutosaveResponse {
        var previewURL: URL
    }

    func createAutosave(with post: RemotePost) async throws -> AutosaveResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.autoSave(post, success: { _, previewURL in
                guard let previewURL = previewURL.flatMap(URL.init) else {
                    return continuation.resume(throwing: URLError(.unknown))
                }
                let response = AutosaveResponse(previewURL: previewURL)
                continuation.resume(returning: response)
            }, failure: {
                continuation.resume(throwing: $0 ?? URLError(.unknown))
            })
        }
    }
}
