import WidgetKit

nonisolated struct KitchenStatusWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let installed = widgets.contains { $0.kind == "BeforeFire.KitchenStatus" }
        Task { @MainActor in
            KitchenWidgetPushRegistration.shared.didChangeToken(pushInfo.token, isInstalled: installed)
        }
    }
}
