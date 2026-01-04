//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具 - WGS-84 转 GCJ-02（中国火星坐标系）
//  解决 GPS 坐标在中国地图上偏移 100-500 米的问题
//

import Foundation
import CoreLocation

/// 坐标转换工具
/// WGS-84（GPS 原始坐标）→ GCJ-02（中国国测局坐标/火星坐标系）
enum CoordinateConverter {

    // MARK: - 常量

    /// 地球长半轴 (WGS-84)
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// π 值
    private static let pi = Double.pi

    // MARK: - Public Methods

    /// WGS-84 转 GCJ-02
    /// - Parameter coordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图使用）
    static func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude
        let lng = coordinate.longitude

        // 判断是否在中国境内，如果不在则不转换
        if isOutOfChina(lat: lat, lng: lng) {
            return coordinate
        }

        // 计算偏移量
        var dLat = transformLat(x: lng - 105.0, y: lat - 35.0)
        var dLng = transformLng(x: lng - 105.0, y: lat - 35.0)

        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let gcjLat = lat + dLat
        let gcjLng = lng + dLng

        return CLLocationCoordinate2D(latitude: gcjLat, longitude: gcjLng)
    }

    /// GCJ-02 转 WGS-84（近似算法）
    /// - Parameter coordinate: GCJ-02 坐标
    /// - Returns: WGS-84 坐标（近似值）
    static func gcj02ToWgs84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude
        let lng = coordinate.longitude

        // 判断是否在中国境内
        if isOutOfChina(lat: lat, lng: lng) {
            return coordinate
        }

        // 使用逆向转换（近似）
        let gcj = wgs84ToGcj02(coordinate)
        let dLat = gcj.latitude - lat
        let dLng = gcj.longitude - lng

        return CLLocationCoordinate2D(
            latitude: lat - dLat,
            longitude: lng - dLng
        )
    }

    /// 批量转换坐标数组 (WGS-84 → GCJ-02)
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断是否在中国境外
    private static func isOutOfChina(lat: Double, lng: Double) -> Bool {
        // 中国经纬度范围（粗略）
        // 纬度：3.86 ~ 53.55
        // 经度：73.66 ~ 135.05
        if lng < 72.004 || lng > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLng(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
