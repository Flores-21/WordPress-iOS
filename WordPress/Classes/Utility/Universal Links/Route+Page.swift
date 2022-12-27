import Foundation

struct NewPageRoute: Route {
    let path = "/page"
    let section: DeepLinkSection? = .editor
    let action: NavigationAction = NewPageNavigationAction()
}

struct NewPageForSiteRoute: Route {
    let path = "/page/:domain"
    let section: DeepLinkSection? = .editor
    let action: NavigationAction = NewPageNavigationAction()
}

struct NewPageNavigationAction: NavigationAction {
    func perform(_ values: [String: String], source: UIViewController? = nil, router: LinkRouter) {
        if let blog = blog(from: values) {
            RootViewControllerCoordinator.sharedPresenter.showPageEditor(forBlog: blog)
        } else {
            RootViewControllerCoordinator.sharedPresenter.showPageEditor()
        }
    }
}
