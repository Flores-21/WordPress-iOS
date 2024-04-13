import UIKit
import WordPressAuthenticator
import Combine
import WordPressUI
import SwiftUI

enum PrepublishingSheetResult {
    /// The user confirms that they want to publish (legacy behavior).
    ///
    /// - note: Deprecated (kahu-offline-mode)
    case confirmed
    /// The sheet published the post (new behavior)
    case published
    /// The user cancelled.
    case cancelled
}

final class PrepublishingViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIAdaptivePresentationControllerDelegate {
    let post: AbstractPost
    let coreDataStack: CoreDataStackSwift
    let persistentStore: UserPersistentRepository

    private let viewModel: PrepublishingViewModel

    var postBlogID: Int? {
        post.blog.dotComID?.intValue
    }

    private lazy var publishSettingsViewModel = PublishSettingsViewModel(post: post)

    private var completion: ((PrepublishingSheetResult) -> ())?

    /// The data source for the table rows, based on the filtered `identifiers`.
    private(set) var options = [PrepublishingOption]()

    private let headerView = PrepublishingHeaderView()
    let tableView = UITableView(frame: .zero, style: .plain)
    private let footerSeparator = UIView()

    private lazy var publishButtonViewModel = PublishButtonViewModel(title: "Publish") { [weak self] in
        self?.buttonPublishTapped()
    }

    private weak var mediaPollingTimer: Timer?
    private let isStandalone: Bool

    init(post: AbstractPost,
         isStandalone: Bool,
         completion: @escaping (PrepublishingSheetResult) -> (),
         coreDataStack: CoreDataStackSwift = ContextManager.shared,
         persistentStore: UserPersistentRepository = UserPersistentStoreFactory.instance()) {
        // If presented from the editor, it make changes to the revision managed by
        // the editor. But for a standalone publishing sheet, it has to manage
        // its own revision.
        self.post = isStandalone ? post._createRevision() : post
        self.isStandalone = isStandalone
        self.viewModel = PrepublishingViewModel(post: post)
        self.completion = completion
        self.coreDataStack = coreDataStack
        self.persistentStore = persistentStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func presentAsSheet(from presentingViewController: UIViewController) {
        let navigationController = UINavigationController(rootViewController: self)
        if UIDevice.isPad() {
            navigationController.modalPresentationStyle = .formSheet
        } else {
            if let sheetController = navigationController.sheetPresentationController {
                if #available(iOS 16, *) {
                    sheetController.detents = [.custom { _ in 510 }, .large()]
                } else {
                    sheetController.detents = [.medium(), .large()]
                }
                sheetController.prefersGrabberVisible = true
                sheetController.preferredCornerRadius = 16
                navigationController.additionalSafeAreaInsets = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
            }
        }
        presentingViewController.present(navigationController, animated: true)
    }

    func refreshOptions() {
        switch post {
        case is Page:
            options = [
                PrepublishingOption(identifier: .visibility),
                PrepublishingOption(identifier: .schedule)
            ]
        case is Post:
            options = [
                PrepublishingOption(identifier: .visibility),
                PrepublishingOption(identifier: .schedule),
                PrepublishingOption(identifier: .tags),
                PrepublishingOption(identifier: .categories)
            ]
            if RemoteFeatureFlag.jetpackSocialImprovements.enabled() && canDisplaySocialRow() {
                options.append(PrepublishingOption(identifier: .autoSharing))
            }
        default:
            wpAssertionFailure("invalid post type")
        }
    }

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshOptions()

        configureHeader()
        configureTableView()
        WPStyleGuide.applyBorderStyle(footerSeparator)

        title = ""

        let stackView = UIStackView(arrangedSubviews: [
            headerView,
            tableView,
            footerSeparator,
            setupPublishButton()
        ])
        stackView.axis = .vertical

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.pinSubviewToSafeArea(stackView)

        view.backgroundColor = .systemBackground

        wpAssert(navigationController?.presentationController != nil)
        navigationController?.presentationController?.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    private func configureHeader() {
        headerView.closeButton.addTarget(self, action: #selector(buttonCloseTapped), for: .touchUpInside)
        headerView.configure(post.blog)
    }

    @objc private func buttonCloseTapped() {
        didCancel()
        presentingViewController?.dismiss(animated: true)
    }

    private func didCancel() {
        getCompletion()?(.cancelled)
        deleteRevisionIfNeeded()
    }

    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
    }

    private func setupPublishButton() -> UIView {
        let footerView = UIView()

        let hostingViewController = UIHostingController(rootView: PublishButton(viewModel: publishButtonViewModel).tint(Color(uiColor: .primary)))
        addChild(hostingViewController)

        footerView.addSubview(hostingViewController.view)
        hostingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        footerView.pinSubviewToSafeArea(hostingViewController.view, insets: Constants.nuxButtonInsets)

        updatePublishButtonLabel()
        updatePublishButtonState()
        mediaPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePublishButtonState()
        }

        return footerView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        footerSeparator.isHidden = tableView.contentSize.height < tableView.bounds.height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated)

        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let isPushingViewController = navigationController?.viewControllers.count ?? 0 > 1
        if isPushingViewController {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    // MARK: - Notifications

    @objc private func appWillTerminate() {
        deleteRevisionIfNeeded()
    }

    private func deleteRevisionIfNeeded() {
        guard isStandalone else { return }
        DDLogDebug("\(self): deleting unsaved changes")
        post.original?.deleteRevision()
        post.managedObjectContext.map(ContextManager.shared.saveContextAndWait)
    }

    // MARK: - UIAdaptivePresentationControllerDelegate {

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didCancel()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = options[indexPath.row]
        let cell = dequeueCell(for: option.type, indexPath: indexPath)

        switch option.type {
        case .textField:
            wpAssertionFailure("no longer suppored")
        case .value:
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = option.title
        default:
            break
        }

        switch option.id {
        case .title:
            wpAssertionFailure("no longer suppored")
        case .tags:
            configureTagCell(cell)
        case .visibility:
            configureVisibilityCell(cell)
        case .schedule:
            configureScheduleCell(cell)
        case .categories:
            configureCategoriesCell(cell)
        case .autoSharing:
            configureSocialCell(cell)
        }

        return cell
    }

    private func dequeueCell(for type: PrepublishingCellType, indexPath: IndexPath) -> WPTableViewCell {
        switch type {
        case .textField:
            wpAssertionFailure("no longer suppored")
            return WPTableViewCell()
        case .value:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.reuseIdentifier) as? WPTableViewCell else {
                return WPTableViewCell.init(style: .value1, reuseIdentifier: Constants.reuseIdentifier)
            }
            return cell
        case .customContainer:
            return WPTableViewCell()
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch options[indexPath.row].id {
        case .tags:
            didTapTagCell()
        case .visibility:
            didTapVisibilityCell()
        case .schedule:
            didTapSchedule(indexPath)
        case .categories:
            didTapCategoriesCell()
        case .autoSharing:
            didTapAutoSharingCell()
        default:
            break
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        headerView.separator.alpha = max(0, min(1, scrollView.contentOffset.y / 60))
    }

    // MARK: – Misc

    func reloadData() {
        refreshOptions()
        tableView.reloadData()
    }

    /// Returns the completion closure and sets it to nil to make sure the screen
    /// only calls it once.
    private func getCompletion() -> ((PrepublishingSheetResult) -> Void)? {
        let completion = self.completion
        self.completion = nil
        return completion
    }

    // MARK: - Tags (Post)

    private func configureTagCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = (post as! Post).tags
    }

    private func didTapTagCell() {
        let post = post as! Post
        let tagPickerViewController = PostTagPickerViewController(tags: post.tags ?? "", blog: post.blog)

        tagPickerViewController.onValueChanged = { [weak self] tags in
            guard let self else { return }
            WPAnalytics.track(.editorPostTagsChanged, properties: Constants.analyticsDefaultProperty)

            (self.post as! Post).tags = tags
            self.reloadData()
        }

        navigationController?.pushViewController(tagPickerViewController, animated: true)
    }

    // MARK: - Categories (Post)

    private func configureCategoriesCell(_ cell: WPTableViewCell) {
        let post = post as! Post
        cell.detailTextLabel?.text = Array(post.categories ?? [])
            .map { $0.categoryName }
            .joined(separator: ",")
    }

    private func didTapCategoriesCell() {
        let post = post as! Post
        let categoriesViewController = PostCategoriesViewController(blog: post.blog, currentSelection: Array(post.categories ?? []), selectionMode: .post)
        categoriesViewController.delegate = self
        categoriesViewController.onCategoriesChanged = { [weak self] in
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(categoriesViewController, animated: true)
    }

    // MARK: - Visibility

    private func configureVisibilityCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = viewModel.visibility.localizedTitle
    }

    private func didTapVisibilityCell() {
        let view = PostVisibilityPicker(visibility: viewModel.visibility) { [weak self] selection in
            guard let self else { return }
            self.viewModel.visibility = selection.visibility
            if selection.visibility == .private {
                self.viewModel.publishDate = nil
                self.updatePublishButtonLabel()
            }
            self.viewModel.password = selection.password
            self.reloadData()
            self.navigationController?.popViewController(animated: true)
        }
        let viewController = UIHostingController(rootView: view)
        viewController.title = PostVisibilityPicker.title
        navigationController?.pushViewController(viewController, animated: true)
    }

    // MARK: - Schedule

    func configureScheduleCell(_ cell: WPTableViewCell) {
        cell.textLabel?.text = Strings.publishDate
        if let publishDate = viewModel.publishDate {
            let formatter = SiteDateFormatters.dateFormatter(for: post.blog.timeZone ?? TimeZone.current, dateStyle: .medium, timeStyle: .short)
            cell.detailTextLabel?.text = formatter.string(from: publishDate)
        } else {
            cell.detailTextLabel?.text = Strings.immediately
        }
        viewModel.visibility == .private ? cell.disable() : cell.enable()
    }

    func didTapSchedule(_ indexPath: IndexPath) {
        let viewController = SchedulingDatePickerViewController()
        viewController.configuration = SchedulingDatePickerConfiguration(date: viewModel.publishDate, timeZone: post.blog.timeZone ?? TimeZone.current) { [weak self] date in
            WPAnalytics.track(.editorPostScheduledChanged, properties: Constants.analyticsDefaultProperty)
            self?.viewModel.publishDate = date
            self?.reloadData()
            self?.updatePublishButtonLabel()
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

    // MARK: - Publish Button

    private func updatePublishButtonState() {
        if let state = PublishButtonState.uploadingState(for: post) {
            publishButtonViewModel.state = state
        } else {
            if case .loading = publishButtonViewModel.state {
                // Do nothing
            } else {
                publishButtonViewModel.state = .default
            }
        }
    }

    private func updatePublishButtonLabel() {
        publishButtonViewModel.title = viewModel.publishButtonTitle
    }

    private func buttonPublishTapped() {
        setLoading(true)
        Task {
            do {
                try await viewModel.publish()
                getCompletion()?(.published)
            } catch {
                setLoading(false)
                publishButtonViewModel.state = .default
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        publishButtonViewModel.state = isLoading ? .loading : .default
        isModalInPresentation = isLoading
        view.isUserInteractionEnabled = !isLoading

        var subviews: [UIView] = [view]
        while let view = subviews.popLast() {
            switch view {
            case let control as UIControl:
                control.isEnabled = !isLoading
            case let cell as UITableViewCell:
                cell.textLabel?.textColor = isLoading ? .secondaryLabel : .label
            default:
                subviews += view.subviews
            }
        }
    }

    // MARK: - Accessibility

    fileprivate enum Constants {
        static let reuseIdentifier = "wpTableViewCell"
        static let nuxButtonInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        static let analyticsDefaultProperty = ["via": "prepublishing_nudges"]
    }
}

extension PrepublishingViewController: PostCategoriesViewControllerDelegate {
    func postCategoriesViewController(_ controller: PostCategoriesViewController, didUpdateSelectedCategories categories: NSSet) {
        WPAnalytics.track(.editorPostCategoryChanged, properties: ["via": "prepublishing_nudges"])
        guard let categories = categories as? Set<PostCategory> else {
             return wpAssertionFailure("incorrect categories")
        }
        (post as! Post).categories = categories
    }
}

struct PrepublishingOption {
    let id: PrepublishingIdentifier
    let title: String
    let type: PrepublishingCellType
}

enum PrepublishingCellType {
    case value
    case textField
    case customContainer
}

extension PrepublishingOption {
    init(identifier: PrepublishingIdentifier) {
        switch identifier {
        case .title:
            self.init(id: .title, title: Strings.postTitle, type: .textField)
        case .schedule:
            self.init(id: .schedule, title: Strings.publishDate, type: .value)
        case .categories:
            self.init(id: .categories, title: Strings.categories, type: .value)
        case .visibility:
            self.init(id: .visibility, title: Strings.visibility, type: .value)
        case .tags:
            self.init(id: .tags, title: Strings.tags, type: .value)
        case .autoSharing:
            self.init(id: .autoSharing, title: Strings.jetpackSocial, type: .customContainer)
        }
    }
}

private final class PrepublishingViewModel {
    private let post: AbstractPost

    var visibility: PostVisibility
    var password: String?
    var publishDate: Date?

    var publishButtonTitle: String {
        let isScheduled = publishDate.map { $0 > .now } ?? false
        return isScheduled ? Strings.schedule : Strings.publish
    }

    private let coordinator = PostCoordinator.shared

    init(post: AbstractPost) {
        self.post = post

        self.visibility = PostVisibility(status: post.status ?? .draft, password: post.password)
        self.password = post.password
        // Ask the user to provide the date every time (ignore the obscure WP dateCreated/dateModified logic)
        self.publishDate = nil
    }

    @MainActor
    func publish() async throws {
        wpAssert(post.isRevision())

        try await coordinator._publish(post.original(), options: .init(
            visibility: visibility,
            password: password,
            publishDate: publishDate
        ))
    }
}

private enum Strings {
    static let publish = NSLocalizedString("prepublishing.publish", value: "Publish", comment: "Primary button label in the pre-publishing sheet")
    static let schedule = NSLocalizedString("prepublishing.schedule", value: "Schedule", comment: "Primary button label in the pre-publishing shee")
    static let publishDate = NSLocalizedString("prepublishing.publishDate", value: "Publish Date", comment: "Label for a cell in the pre-publishing sheet")
    static let postTitle = NSLocalizedString("prepublishing.postTitle", value: "Title", comment: "Placeholder for a cell in the pre-publishing sheet")
    static let visibility = NSLocalizedString("prepublishing.visibility", value: "Visibility", comment: "Label for a cell in the pre-publishing sheet")
    static let categories = NSLocalizedString("prepublishing.categories", value: "Categories", comment: "Label for a cell in the pre-publishing sheet")
    static let tags = NSLocalizedString("prepublishing.tags", value: "Tags", comment: "Label for a cell in the pre-publishing sheet")
    static let jetpackSocial = NSLocalizedString("prepublishing.jetpackSocial", value: "Jetpack Social", comment: "Label for a cell in the pre-publishing sheet")
    static let immediately = NSLocalizedString("prepublishing.publishDateImmediately", value: "Immediately", comment: "Placeholder value for a publishing date in the prepublishing sheet when the date is not selected")
}
