import Foundation
import SwiftUI
import DesignSystem

struct PostNoticePublishSuccessView: View {
    let post: Post
    let context: Context
    let onDoneTapped: () -> Void

    var body: some View {
        Form {
            Section { header }
            Section { actions }
                .tint(Color.primary)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDoneTapped, label: {
                Text(Strings.done)
                    .font(.headline)
            })
            .tint(.primary)
            .padding(.bottom, 16)
        }
        .onAppear {
            WPAnalytics.track(.postEpilogueDisplayed)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.title)
                    .font(.title3.weight(.semibold))

                Text(post.titleForDisplay())
                    .font(.subheadline)
                    .lineLimit(2)

                let domain = post.blog.primaryDomainAddress
                if !domain.isEmpty {
                    Button(action: buttonOpenDomainTapped) {
                        Text(domain)
                            .font(.footnote)
                            .lineLimit(1)
                    }
                    .tint(.secondary)
                }
            }

            Spacer()

            Image("post-published")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90)
        }
        .dynamicTypeSize(.medium ... .accessibility3)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: buttonViewTapped, label: {
            HStack {
                Text(Strings.view)
                Spacer()
                Image(systemName: "safari")
            }
        })
        Button(action: buttonShareTapped, label: {
            HStack {
                Text(Strings.share)
                Spacer()
                Image(systemName: "square.and.arrow.up")
            }
        })
        if BlazeHelper.isBlazeFlagEnabled() && post.canBlaze {
            Button(action: buttonBlazeTapped, label: {
                HStack {
                    Text(Strings.promoteWithBlaze)
                    Spacer()
                    Image("icon-blaze")
                }
            })
        }
    }

    private func buttonOpenDomainTapped() {
        guard let url = URL(string: post.blog.primaryDomainAddress) else { return }
        UIApplication.shared.open(url)
    }

    private func buttonViewTapped() {
        guard let presenter = context.viewController else {
            return wpAssertionFailure("presenter missing")
        }
        WPAnalytics.track(.postEpilogueView)
        let controller = PreviewWebKitViewController(post: post, source: "edit_post_preview")
        controller.trackOpenEvent()
        let navWrapper = LightNavigationController(rootViewController: controller)
        presenter.present(navWrapper, animated: true)
    }

    private func buttonShareTapped() {
        guard let presenter = context.viewController else {
            return wpAssertionFailure("presenter missing")
        }
        WPAnalytics.track(.postEpilogueShare)
        let shareController = PostSharingController()
        shareController.sharePost(post, fromView: presenter.view, inViewController: presenter)
    }

    private func buttonBlazeTapped() {
        guard let presenter = context.viewController else {
            return wpAssertionFailure("presenter missing")
        }
        BlazeEventsTracker.trackEntryPointTapped(for: .publishSuccessView)
        BlazeFlowCoordinator.presentBlaze(in: presenter, source: .publishSuccessView, blog: post.blog, post: post)
    }

    final class Context {
        weak var viewController: UIViewController?
    }
}

private enum Strings {
    static let title = NSLocalizedString("publishSuccessView.title", value: "Post published!", comment: "Post publish success view: title")
    static let trafficSectionTitle = NSLocalizedString("publishSuccessView.trafficSectionTitle", value: "Get more traffic:", comment: "Post publish success view: section 'Get more traffic:' title")
    static let view = NSLocalizedString("publishSuccessView.view", value: "View post", comment: "Post publish success view: button 'View post'")
    static let share = NSLocalizedString("publishSuccessView.share", value: "Share post", comment: "Post publish success view: button 'Share post'")
    static let promoteWithBlaze = NSLocalizedString("publishSuccessView.promoteWithBlaze", value: "Promote with Blaze", comment: "Post publish success view: button 'Promote with Blaze'")
    static let done = NSLocalizedString("publishSuccessView.done", value: "Done", comment: "Post publish success view: button 'Done'")
}
