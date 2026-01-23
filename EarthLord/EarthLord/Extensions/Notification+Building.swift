//
//  Notification+Building.swift
//  EarthLord
//
//  通知名称定义
//

import Foundation

// MARK: - 领地和建筑相关通知
extension Notification.Name {
    /// 领地更新通知（重命名、删除等）
    static let territoryUpdated = Notification.Name("territoryUpdated")

    /// 建筑更新通知（建造完成、拆除等）
    static let buildingUpdated = Notification.Name("buildingUpdated")

    /// 建筑列表刷新通知
    static let buildingListRefresh = Notification.Name("buildingListRefresh")
}
