import UIKit

extension PostCoordinator {
    static func makeUploadSuccessNotice(for post: AbstractPost, isExistingPost: Bool = false) -> Notice {
        var message: String {
            let title = post.titleForDisplay() ?? ""
            if !title.isEmpty {
                return title
            }
            return post.blog.displayURL as String? ?? ""
        }
        let isPublished = post.status == .publish
        return Notice(title: Strings.publishSuccessTitle(for: post, isExistingPost: isExistingPost),
                      message: message,
                      feedbackType: .success,
                      notificationInfo: makeUploadSuccessNotificationInfo(for: post, isExistingPost: isExistingPost),
                      actionTitle: isPublished ? Strings.view : nil,
                      actionHandler: { _ in
            PostNoticeNavigationCoordinator.presentPostEpilogue(for: post)
        })
    }

    private static func makeUploadSuccessNotificationInfo(for post: AbstractPost, isExistingPost: Bool) -> NoticeNotificationInfo {
        let status = Strings.publishSuccessTitle(for: post, isExistingPost: isExistingPost)
        var title: String {
            let title = post.titleForDisplay() ?? ""
            guard !title.isEmpty else {
                return status
            }
            return "“\(title)” \(status)"
        }
        var body: String {
            post.blog.displayURL as String? ?? ""
        }
        return NoticeNotificationInfo(
            identifier: UUID().uuidString,
            categoryIdentifier: InteractiveNotificationsManager.NoteCategoryDefinition.postUploadSuccess.rawValue,
            title: title,
            body: body,
            userInfo: [
                PostNoticeUserInfoKey.postID: post.objectID.uriRepresentation().absoluteString
            ])
    }
}

private enum Strings {
    static let view = NSLocalizedString("postNotice.view", value: "View", comment: "Button title. Displays a summary / sharing screen for a specific post.")

    static func publishSuccessTitle(for post: AbstractPost, isExistingPost: Bool = false) -> String {
        switch post {
        case let post as Post:
            switch post.status {
            case .draft:
                return NSLocalizedString("postNotice.postDraftCreated", value: "Post draft uploaded", comment: "Title of notification displayed when a post has been successfully saved as a draft.")
            case .scheduled:
                return NSLocalizedString("postNotice.postScheduled", value: "Post scheduled", comment: "Title of notification displayed when a post has been successfully scheduled.")
            case .pending:
                return NSLocalizedString("postNotice.postPendingReview", value: "Post pending review", comment: "Title of notification displayed when a post has been successfully saved as a draft.")
            default:
                if !isExistingPost {
                    return NSLocalizedString("postNotice.postPublished", value: "Post published", comment: "Title of notification displayed when a post has been successfully published.")
                } else {
                    return NSLocalizedString("postNotice.postUpdated", value: "Post updated", comment: "Title of notification displayed when a post has been successfully updated.")
                }
            }
        case let page as Page:
            switch page.status {
            case .draft:
                return NSLocalizedString("postNotice.pageDraftCreated", value: "Page draft uploaded", comment: "Title of notification displayed when a page has been successfully saved as a draft.")
            case .scheduled:
                return NSLocalizedString("postNotice.pageScheduled", value: "Page scheduled", comment: "Title of notification displayed when a page has been successfully scheduled.")
            case .pending:
                return NSLocalizedString("postNotice.pagePending", value: "Page pending review", comment: "Title of notification displayed when a page has been successfully saved as a draft.")
            default:
                if !isExistingPost {
                    return NSLocalizedString("postNotice.pagePublished", value: "Page published", comment: "Title of notification displayed when a page has been successfully published.")
                } else {
                    return NSLocalizedString("postNotice.pageUpdated", value: "Page updated", comment: "Title of notification displayed when a page has been successfully updated.")
                }
            }
        default:
            assertionFailure("Unexpected post type: \(post)")
            return ""
        }
    }
}
