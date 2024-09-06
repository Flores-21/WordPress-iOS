import SwiftUI
import WordPressShared

struct BlogListSiteView: View {
    let site: BlogListSiteViewModel
    var style: Style = .default

    enum Style {
        case `default`, sidebar
    }

    var body: some View {
        HStack(alignment: .center, spacing: style == .default ? 16 : 10) {
            let icon = style == .default ? site.icon : site.makeIcon(with: .small)
            SiteIconView(viewModel: icon)
                .frame(width: icon.size.width, height: icon.size.width)
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    Text(site.title)
                        .font(.callout.weight(.medium))
                    if let badge = site.badge {
                        BlogListBadgeView(badge: badge)
                    }
                }
                Text(site.domain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
    }
}

private struct BlogListBadgeView: View {
    let badge: BlogListSiteViewModel.Badge

    var body: some View {
        Text(badge.title.uppercased())
            .lineLimit(1)
            .font(.caption2.weight(.semibold))
            .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
            .background(badge.color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(height: 10) // Make sure it doesn't affect the layout and spacing
    }
}

struct BlogListSiteViewModel: Identifiable {
    let id: TaggedManagedObjectID<Blog>
    let title: String
    let domain: String
    let icon: SiteIconViewModel
    let searchTags: String
    let siteURL: URL?
    let badge: Badge?

    struct Badge {
        let title: String
        let color: Color
    }

    func makeIcon(with size: SiteIconViewModel.Size) -> SiteIconViewModel {
        let context = ContextManager.shared.mainContext
        guard let blog = try? context.existingObject(with: id) else { return icon }

        return SiteIconViewModel(blog: blog, size: size)
    }

    init(blog: Blog) {
        self.id = TaggedManagedObjectID(blog)
        self.title = blog.title ?? "–"
        self.domain = blog.displayURL as String? ?? ""
        self.icon = SiteIconViewModel(blog: blog)
        self.siteURL = blog.url.flatMap(URL.init)

        // By adding displayURL _after_ the title, it loweres its weight in search
        self.searchTags = "\(title) \(domain)"

        if (blog.getOption(name: "is_wpcom_staging_site") as Bool?) == true {
            badge = Badge(title: Strings.staging, color: Color.yellow.opacity(0.33))
        } else {
            badge = nil
        }
    }

    func buttonViewTapped() {
        guard let siteURL else {
            return wpAssertionFailure("missing-url")
        }
        WPAnalytics.track(.siteListViewTapped)
        UIApplication.shared.open(siteURL)
    }

    func buttonCopyLinkTapped() {
        UIPasteboard.general.string = siteURL?.absoluteString
        WPAnalytics.track(.siteListCopyLinktapped)
    }
}

private enum Strings {
    static let staging = NSLocalizedString("blogList.siteBadge.staging", value: "Staging", comment: "Badge title in site list")
}
