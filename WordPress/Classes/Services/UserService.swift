import Foundation
import WordPressAPI
import WordPressUI

/// UserService is responsible for fetching user acounts via the .org REST API – it's the replacement for `UsersService` (the XMLRPC-based approach)
///
struct UserService {

    final class ActionDispatcher: UserManagementActionDispatcher {

        private let client: WordPressClient

        init(client: WordPressClient) {
            self.client = client
            super.init()
        }

        override func setNewPassword(id: Int32, newPassword: String) async throws {
            _ = try await client.api.users.update(
                userId: Int32(id),
                params: UserUpdateParams(password: newPassword)
            )
        }

        override func deleteUser(id: Int32, reassigningPostsTo newUserId: Int32) async throws {
            _ = try await client.api.users.delete(
                userId: id,
                params: UserDeleteParams(reassign: newUserId)
            )
        }
    }

    private let apiClient: WordPressClient
    private let currentUserId: Int

    let actionDispatcher: ActionDispatcher

    init(api: WordPressClient, currentUserId: Int) {
        self.apiClient = api
        self.currentUserId = currentUserId
        self.actionDispatcher = ActionDispatcher(client: apiClient)
    }
}

extension UserService: WordPressUI.UserDataProvider {
    func fetchCurrentUserCan(_ capability: String) async throws -> Bool {
        try await apiClient.api.users.retrieveMeWithEditContext().capabilities.keys.contains(capability)
    }

    func fetchUsers() async throws -> [WordPressUI.DisplayUser] {
        try await apiClient.api.users.listWithEditContext(params: UserListParams()).compactMap {

            guard let role = $0.roles.first else {
                return nil
            }

            return DisplayUser(
                id: $0.id,
                handle: $0.slug,
                username: $0.username,
                firstName: $0.firstName,
                lastName: $0.lastName,
                displayName: $0.username,
                profilePhotoUrl: profilePhotoUrl(for: $0),
                role: role,
                emailAddress: $0.email,
                websiteUrl: $0.link,
                biography: $0.description
            )
        }
    }

    func profilePhotoUrl(for user: UserWithEditContext) -> URL? {
        guard let rawUrl = user.avatarUrls?.first?.value else { // This results in a very low-res avatar
            return nil
        }

        return URL(string: rawUrl)
    }
}
