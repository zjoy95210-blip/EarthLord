//
//  SupabaseService.swift
//  EarthLord
//
//  Supabase 数据服务层
//

import Foundation
import Supabase
import Observation

// MARK: - Supabase Service
/// Supabase 数据操作服务
@MainActor
@Observable
final class SupabaseService {
    static let shared = SupabaseService()

    private init() {}

    // MARK: - Profile Operations

    /// 获取当前用户资料
    func getCurrentProfile() async throws -> Profile? {
        guard let userId = supabase.auth.currentUser?.id else {
            return nil
        }

        let profile: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return profile
    }

    /// 获取指定用户资料
    func getProfile(userId: UUID) async throws -> Profile {
        let profile: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return profile
    }

    /// 更新用户资料
    func updateProfile(userId: UUID, update: ProfileUpdate) async throws {
        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Territory Operations

    /// 获取用户的所有领地
    func getTerritories(userId: UUID) async throws -> [Territory] {
        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return territories
    }

    /// 获取所有领地（用于地图显示）
    func getAllTerritories() async throws -> [Territory] {
        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return territories
    }

    /// 创建新领地
    func createTerritory(_ territory: TerritoryInsert) async throws -> Territory {
        let newTerritory: Territory = try await supabase
            .from("territories")
            .insert(territory)
            .select()
            .single()
            .execute()
            .value

        return newTerritory
    }

    /// 更新领地
    func updateTerritory(id: UUID, name: String) async throws {
        try await supabase
            .from("territories")
            .update(["name": name])
            .eq("id", value: id)
            .execute()
    }

    /// 删除领地
    func deleteTerritory(id: UUID) async throws {
        try await supabase
            .from("territories")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - POI Operations

    /// 获取所有 POI
    func getAllPOIs() async throws -> [POI] {
        let pois: [POI] = try await supabase
            .from("pois")
            .select()
            .execute()
            .value

        return pois
    }

    /// 获取指定类型的 POI
    func getPOIs(type: POIType) async throws -> [POI] {
        let pois: [POI] = try await supabase
            .from("pois")
            .select()
            .eq("poi_type", value: type.rawValue)
            .execute()
            .value

        return pois
    }

    /// 获取用户发现的 POI
    func getDiscoveredPOIs(userId: UUID) async throws -> [POI] {
        let pois: [POI] = try await supabase
            .from("pois")
            .select()
            .eq("discovered_by", value: userId)
            .order("discovered_at", ascending: false)
            .execute()
            .value

        return pois
    }

    /// 创建新 POI
    func createPOI(_ poi: POIInsert) async throws -> POI {
        let newPOI: POI = try await supabase
            .from("pois")
            .insert(poi)
            .select()
            .single()
            .execute()
            .value

        return newPOI
    }

    /// 检查 POI 是否已存在
    func poiExists(id: String) async throws -> Bool {
        let count = try await supabase
            .from("pois")
            .select("id", head: true, count: .exact)
            .eq("id", value: id)
            .execute()
            .count

        return (count ?? 0) > 0
    }

    // MARK: - Connection Test

    /// 测试数据库连接
    func testConnection() async throws -> Bool {
        // 尝试查询 profiles 表来测试连接
        let _: [Profile] = try await supabase
            .from("profiles")
            .select()
            .limit(1)
            .execute()
            .value

        return true
    }
}

// MARK: - Auth Service Extension
extension SupabaseService {
    /// 获取当前登录用户 ID
    var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }

    /// 检查用户是否已登录
    var isAuthenticated: Bool {
        supabase.auth.currentUser != nil
    }
}
