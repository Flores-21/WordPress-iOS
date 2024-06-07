import Foundation
import CocoaLumberjack
import WordPressShared
import WordPressFlux

struct PublishSettingsViewModel {
    enum State {
        case scheduled(Date)
        case published(Date)
        case immediately

        init(post: AbstractPost) {
            if let date = post.dateCreated {
                self = date > .now ? .scheduled(date) : .published(date)
            } else {
                self = .immediately
            }
        }
    }

    private(set) var state: State
    let timeZone: TimeZone
    let title: String?

    var detailString: String {
        switch state {
        case .scheduled(let date), .published(let date):
            return dateTimeFormatter.string(from: date)
        case .immediately:
            return NSLocalizedString("Immediately", comment: "Undated post time label")
        }
    }

    private let post: AbstractPost

    var isRequired: Bool {
        if post.original().isStatus(in: [.publish, .publishPrivate, .scheduled]) {
            // You can't remove the publish date for these statuses.
            return true
        }
        if post.original().isStatus(in: [.draft, .pending]) && !(post.original?.shouldPublishImmediately() ?? false) {
            // If you ever set a publish date for a draft, the API that the app
            // uses doesn't allow you to remove it.
            return true
        }
        return false
    }

    let dateFormatter: DateFormatter
    let dateTimeFormatter: DateFormatter

    init(post: AbstractPost, context: NSManagedObjectContext = ContextManager.sharedInstance().mainContext) {
        state = State(post: post)

        self.post = post

        title = post.postTitle
        timeZone = post.blog.timeZone ?? TimeZone.current

        dateFormatter = SiteDateFormatters.dateFormatter(for: timeZone, dateStyle: .long, timeStyle: .none)
        dateTimeFormatter = SiteDateFormatters.dateFormatter(for: timeZone, dateStyle: .medium, timeStyle: .short)
    }

    var date: Date? {
        switch state {
        case .scheduled(let date), .published(let date):
            return date
        case .immediately:
            return nil
        }
    }

    mutating func setDate(_ date: Date?) {
        post.dateCreated = date
        state = State(post: post)
    }
}
