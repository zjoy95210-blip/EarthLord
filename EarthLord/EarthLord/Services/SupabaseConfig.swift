//
//  SupabaseConfig.swift
//  EarthLord
//
//  Supabase 配置文件
//

import Foundation
import Supabase

// MARK: - Supabase Configuration
enum SupabaseConfig {
    /// Supabase 项目 URL
    static let supabaseURL = URL(string: "https://svxpiosqufxdhwlcpfhm.supabase.co")!

    /// Supabase Anon Key (公开密钥，可安全嵌入客户端)
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2eHBpb3NxdWZ4ZGh3bGNwZmhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY3NTg5MDAsImV4cCI6MjA4MjMzNDkwMH0.xxQVOOqbsHYyv7B_zyD7h2Vu5WnqFXHV-dVDXOBa5Vg"

    /// 项目 Reference ID
    static let projectRef = "svxpiosqufxdhwlcpfhm"
}

// MARK: - Supabase Client Singleton
/// 全局 Supabase 客户端实例
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.supabaseURL,
    supabaseKey: SupabaseConfig.supabaseAnonKey,
    options: .init(
        auth: .init(
            // 采用新的 session 行为，本地存储的 session 总是被发出
            // 参考: https://github.com/supabase/supabase-swift/pull/822
            emitLocalSessionAsInitialSession: true
        )
    )
)
