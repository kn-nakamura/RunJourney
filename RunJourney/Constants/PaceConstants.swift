import Foundation

/// 各 PaceRaceType の距離・ラップ間隔の設定。
/// Web 版 `src/constants/paceConfig.ts:3-39` をそのまま移植。
enum PaceConstants {
    static let configs: [PaceRaceType: PaceRaceConfig] = [
        .fiveK:     PaceRaceConfig(key: .fiveK,     distanceKm: 5,        lapIntervalKm: 1),
        .tenK:      PaceRaceConfig(key: .tenK,      distanceKm: 10,       lapIntervalKm: 1),
        .half:      PaceRaceConfig(key: .half,      distanceKm: 21.0975,  lapIntervalKm: 5),
        .full:      PaceRaceConfig(key: .full,      distanceKm: 42.195,   lapIntervalKm: 5),
        .ultra100k: PaceRaceConfig(key: .ultra100k, distanceKm: 100,      lapIntervalKm: 10),
        // .custom は customDistanceKm を別途参照する
    ]

    /// 距離別のデフォルト目標タイム (秒)。Web 版 `paceConfig.ts:43-49` と同値。
    static let defaultGoalTimes: [PaceRaceType: Int] = [
        .fiveK:     25 * 60,        // 25:00
        .tenK:      50 * 60,        // 50:00
        .half:      2 * 3600,       // 2:00:00
        .full:      4 * 3600,       // 4:00:00
        .ultra100k: 12 * 3600,      // 12:00:00
    ]

    /// 表示順序
    static let order: [PaceRaceType] = [.fiveK, .tenK, .half, .full, .ultra100k, .custom]
}

// MARK: - Sub-XX Quick Targets

struct SubTarget: Hashable {
    let label: String
    let seconds: Int
}

struct SubTargetGroup: Hashable {
    let groupLabel: String
    let items: [SubTarget]
}

/// 目標タイムのクイック設定 (Sub-X グループ)。
/// Web 版 `src/components/pace/GoalTimeSelector.tsx:17-389` の `SUB_TARGET_GROUPS` を完全移植。
enum SubTargetGroups {
    static let all: [PaceRaceType: [SubTargetGroup]] = [
        .fiveK: [
            SubTargetGroup(groupLabel: "Sub 15", items: [
                SubTarget(label: "13:00", seconds: 13 * 60),
                SubTarget(label: "13:30", seconds: 13 * 60 + 30),
                SubTarget(label: "14:00", seconds: 14 * 60),
                SubTarget(label: "14:30", seconds: 14 * 60 + 30),
                SubTarget(label: "15:00", seconds: 15 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 17", items: [
                SubTarget(label: "15:30", seconds: 15 * 60 + 30),
                SubTarget(label: "16:00", seconds: 16 * 60),
                SubTarget(label: "16:30", seconds: 16 * 60 + 30),
                SubTarget(label: "17:00", seconds: 17 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 20", items: [
                SubTarget(label: "17:30", seconds: 17 * 60 + 30),
                SubTarget(label: "18:00", seconds: 18 * 60),
                SubTarget(label: "18:30", seconds: 18 * 60 + 30),
                SubTarget(label: "19:00", seconds: 19 * 60),
                SubTarget(label: "19:30", seconds: 19 * 60 + 30),
                SubTarget(label: "20:00", seconds: 20 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 25", items: [
                SubTarget(label: "21:00", seconds: 21 * 60),
                SubTarget(label: "22:00", seconds: 22 * 60),
                SubTarget(label: "23:00", seconds: 23 * 60),
                SubTarget(label: "24:00", seconds: 24 * 60),
                SubTarget(label: "25:00", seconds: 25 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 30", items: [
                SubTarget(label: "26:00", seconds: 26 * 60),
                SubTarget(label: "27:00", seconds: 27 * 60),
                SubTarget(label: "28:00", seconds: 28 * 60),
                SubTarget(label: "29:00", seconds: 29 * 60),
                SubTarget(label: "30:00", seconds: 30 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 40", items: [
                SubTarget(label: "32:00", seconds: 32 * 60),
                SubTarget(label: "35:00", seconds: 35 * 60),
                SubTarget(label: "37:00", seconds: 37 * 60),
                SubTarget(label: "40:00", seconds: 40 * 60),
            ]),
        ],
        .tenK: [
            SubTargetGroup(groupLabel: "Sub 30", items: [
                SubTarget(label: "27:00", seconds: 27 * 60),
                SubTarget(label: "27:30", seconds: 27 * 60 + 30),
                SubTarget(label: "28:00", seconds: 28 * 60),
                SubTarget(label: "28:30", seconds: 28 * 60 + 30),
                SubTarget(label: "29:00", seconds: 29 * 60),
                SubTarget(label: "29:30", seconds: 29 * 60 + 30),
                SubTarget(label: "30:00", seconds: 30 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 35", items: [
                SubTarget(label: "31:00", seconds: 31 * 60),
                SubTarget(label: "32:00", seconds: 32 * 60),
                SubTarget(label: "33:00", seconds: 33 * 60),
                SubTarget(label: "34:00", seconds: 34 * 60),
                SubTarget(label: "35:00", seconds: 35 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 40", items: [
                SubTarget(label: "36:00", seconds: 36 * 60),
                SubTarget(label: "37:00", seconds: 37 * 60),
                SubTarget(label: "38:00", seconds: 38 * 60),
                SubTarget(label: "39:00", seconds: 39 * 60),
                SubTarget(label: "40:00", seconds: 40 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 50", items: [
                SubTarget(label: "42:00", seconds: 42 * 60),
                SubTarget(label: "44:00", seconds: 44 * 60),
                SubTarget(label: "46:00", seconds: 46 * 60),
                SubTarget(label: "48:00", seconds: 48 * 60),
                SubTarget(label: "50:00", seconds: 50 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 60", items: [
                SubTarget(label: "52:00", seconds: 52 * 60),
                SubTarget(label: "54:00", seconds: 54 * 60),
                SubTarget(label: "56:00", seconds: 56 * 60),
                SubTarget(label: "58:00", seconds: 58 * 60),
                SubTarget(label: "60:00", seconds: 60 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 80", items: [
                SubTarget(label: "65:00", seconds: 65 * 60),
                SubTarget(label: "70:00", seconds: 70 * 60),
                SubTarget(label: "75:00", seconds: 75 * 60),
                SubTarget(label: "80:00", seconds: 80 * 60),
            ]),
        ],
        .half: [
            SubTargetGroup(groupLabel: "Sub 1:00", items: [
                SubTarget(label: "0:56:00", seconds: 56 * 60),
                SubTarget(label: "0:57:00", seconds: 57 * 60),
                SubTarget(label: "0:58:00", seconds: 58 * 60),
                SubTarget(label: "0:59:00", seconds: 59 * 60),
                SubTarget(label: "1:00:00", seconds: 60 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 1:10", items: [
                SubTarget(label: "1:01:00", seconds: 61 * 60),
                SubTarget(label: "1:03:00", seconds: 63 * 60),
                SubTarget(label: "1:05:00", seconds: 65 * 60),
                SubTarget(label: "1:07:00", seconds: 67 * 60),
                SubTarget(label: "1:10:00", seconds: 70 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 1:20", items: [
                SubTarget(label: "1:11:00", seconds: 71 * 60),
                SubTarget(label: "1:13:00", seconds: 73 * 60),
                SubTarget(label: "1:15:00", seconds: 75 * 60),
                SubTarget(label: "1:17:00", seconds: 77 * 60),
                SubTarget(label: "1:20:00", seconds: 80 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 1:30", items: [
                SubTarget(label: "1:21:00", seconds: 81 * 60),
                SubTarget(label: "1:23:00", seconds: 83 * 60),
                SubTarget(label: "1:25:00", seconds: 85 * 60),
                SubTarget(label: "1:27:00", seconds: 87 * 60),
                SubTarget(label: "1:30:00", seconds: 90 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 1:45", items: [
                SubTarget(label: "1:31:00", seconds: 91 * 60),
                SubTarget(label: "1:35:00", seconds: 95 * 60),
                SubTarget(label: "1:40:00", seconds: 100 * 60),
                SubTarget(label: "1:45:00", seconds: 105 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 2:00", items: [
                SubTarget(label: "1:50:00", seconds: 110 * 60),
                SubTarget(label: "1:55:00", seconds: 115 * 60),
                SubTarget(label: "2:00:00", seconds: 120 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 2:30", items: [
                SubTarget(label: "2:05:00", seconds: 125 * 60),
                SubTarget(label: "2:10:00", seconds: 130 * 60),
                SubTarget(label: "2:15:00", seconds: 135 * 60),
                SubTarget(label: "2:20:00", seconds: 140 * 60),
                SubTarget(label: "2:25:00", seconds: 145 * 60),
                SubTarget(label: "2:30:00", seconds: 150 * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 3:00", items: [
                SubTarget(label: "2:40:00", seconds: 160 * 60),
                SubTarget(label: "2:50:00", seconds: 170 * 60),
                SubTarget(label: "3:00:00", seconds: 180 * 60),
            ]),
        ],
        .full: [
            SubTargetGroup(groupLabel: "Sub 2", items: [
                SubTarget(label: "1:58:00", seconds: (1 * 60 + 58) * 60),
                SubTarget(label: "1:59:00", seconds: (1 * 60 + 59) * 60),
                SubTarget(label: "2:00:00", seconds: 2 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 2:30", items: [
                SubTarget(label: "2:05:00", seconds: (2 * 60 + 5) * 60),
                SubTarget(label: "2:10:00", seconds: (2 * 60 + 10) * 60),
                SubTarget(label: "2:15:00", seconds: (2 * 60 + 15) * 60),
                SubTarget(label: "2:20:00", seconds: (2 * 60 + 20) * 60),
                SubTarget(label: "2:25:00", seconds: (2 * 60 + 25) * 60),
                SubTarget(label: "2:30:00", seconds: (2 * 60 + 30) * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 2:50", items: [
                SubTarget(label: "2:35:00", seconds: (2 * 60 + 35) * 60),
                SubTarget(label: "2:40:00", seconds: (2 * 60 + 40) * 60),
                SubTarget(label: "2:45:00", seconds: (2 * 60 + 45) * 60),
                SubTarget(label: "2:50:00", seconds: (2 * 60 + 50) * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 3", items: [
                SubTarget(label: "2:51:00", seconds: (2 * 60 + 51) * 60),
                SubTarget(label: "2:53:00", seconds: (2 * 60 + 53) * 60),
                SubTarget(label: "2:55:00", seconds: (2 * 60 + 55) * 60),
                SubTarget(label: "2:57:00", seconds: (2 * 60 + 57) * 60),
                SubTarget(label: "3:00:00", seconds: 3 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 3:30", items: [
                SubTarget(label: "3:05:00", seconds: (3 * 60 + 5) * 60),
                SubTarget(label: "3:10:00", seconds: (3 * 60 + 10) * 60),
                SubTarget(label: "3:15:00", seconds: (3 * 60 + 15) * 60),
                SubTarget(label: "3:20:00", seconds: (3 * 60 + 20) * 60),
                SubTarget(label: "3:25:00", seconds: (3 * 60 + 25) * 60),
                SubTarget(label: "3:30:00", seconds: (3 * 60 + 30) * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 4", items: [
                SubTarget(label: "3:35:00", seconds: (3 * 60 + 35) * 60),
                SubTarget(label: "3:40:00", seconds: (3 * 60 + 40) * 60),
                SubTarget(label: "3:45:00", seconds: (3 * 60 + 45) * 60),
                SubTarget(label: "3:50:00", seconds: (3 * 60 + 50) * 60),
                SubTarget(label: "3:55:00", seconds: (3 * 60 + 55) * 60),
                SubTarget(label: "4:00:00", seconds: 4 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 4:30", items: [
                SubTarget(label: "4:05:00", seconds: (4 * 60 + 5) * 60),
                SubTarget(label: "4:10:00", seconds: (4 * 60 + 10) * 60),
                SubTarget(label: "4:15:00", seconds: (4 * 60 + 15) * 60),
                SubTarget(label: "4:20:00", seconds: (4 * 60 + 20) * 60),
                SubTarget(label: "4:25:00", seconds: (4 * 60 + 25) * 60),
                SubTarget(label: "4:30:00", seconds: (4 * 60 + 30) * 60),
            ]),
            SubTargetGroup(groupLabel: "Sub 5", items: [
                SubTarget(label: "4:35:00", seconds: (4 * 60 + 35) * 60),
                SubTarget(label: "4:40:00", seconds: (4 * 60 + 40) * 60),
                SubTarget(label: "4:45:00", seconds: (4 * 60 + 45) * 60),
                SubTarget(label: "4:50:00", seconds: (4 * 60 + 50) * 60),
                SubTarget(label: "4:55:00", seconds: (4 * 60 + 55) * 60),
                SubTarget(label: "5:00:00", seconds: 5 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 6", items: [
                SubTarget(label: "5:10:00", seconds: (5 * 60 + 10) * 60),
                SubTarget(label: "5:20:00", seconds: (5 * 60 + 20) * 60),
                SubTarget(label: "5:30:00", seconds: (5 * 60 + 30) * 60),
                SubTarget(label: "5:40:00", seconds: (5 * 60 + 40) * 60),
                SubTarget(label: "5:50:00", seconds: (5 * 60 + 50) * 60),
                SubTarget(label: "6:00:00", seconds: 6 * 3600),
            ]),
        ],
        .ultra100k: [
            SubTargetGroup(groupLabel: "Sub 7h", items: [
                SubTarget(label: "6:30:00", seconds: (6 * 60 + 30) * 60),
                SubTarget(label: "6:40:00", seconds: (6 * 60 + 40) * 60),
                SubTarget(label: "6:50:00", seconds: (6 * 60 + 50) * 60),
                SubTarget(label: "7:00:00", seconds: 7 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 8h", items: [
                SubTarget(label: "7:15:00", seconds: (7 * 60 + 15) * 60),
                SubTarget(label: "7:30:00", seconds: (7 * 60 + 30) * 60),
                SubTarget(label: "7:45:00", seconds: (7 * 60 + 45) * 60),
                SubTarget(label: "8:00:00", seconds: 8 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 9h", items: [
                SubTarget(label: "8:15:00", seconds: (8 * 60 + 15) * 60),
                SubTarget(label: "8:30:00", seconds: (8 * 60 + 30) * 60),
                SubTarget(label: "8:45:00", seconds: (8 * 60 + 45) * 60),
                SubTarget(label: "9:00:00", seconds: 9 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 10h", items: [
                SubTarget(label: "9:15:00", seconds: (9 * 60 + 15) * 60),
                SubTarget(label: "9:30:00", seconds: (9 * 60 + 30) * 60),
                SubTarget(label: "9:45:00", seconds: (9 * 60 + 45) * 60),
                SubTarget(label: "10:00:00", seconds: 10 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 12h", items: [
                SubTarget(label: "10:30:00", seconds: (10 * 60 + 30) * 60),
                SubTarget(label: "11:00:00", seconds: 11 * 3600),
                SubTarget(label: "11:30:00", seconds: (11 * 60 + 30) * 60),
                SubTarget(label: "12:00:00", seconds: 12 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 14h", items: [
                SubTarget(label: "12:30:00", seconds: (12 * 60 + 30) * 60),
                SubTarget(label: "13:00:00", seconds: 13 * 3600),
                SubTarget(label: "13:30:00", seconds: (13 * 60 + 30) * 60),
                SubTarget(label: "14:00:00", seconds: 14 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 16h", items: [
                SubTarget(label: "14:30:00", seconds: (14 * 60 + 30) * 60),
                SubTarget(label: "15:00:00", seconds: 15 * 3600),
                SubTarget(label: "15:30:00", seconds: (15 * 60 + 30) * 60),
                SubTarget(label: "16:00:00", seconds: 16 * 3600),
            ]),
            SubTargetGroup(groupLabel: "Sub 18h", items: [
                SubTarget(label: "16:30:00", seconds: (16 * 60 + 30) * 60),
                SubTarget(label: "17:00:00", seconds: 17 * 3600),
                SubTarget(label: "17:30:00", seconds: (17 * 60 + 30) * 60),
                SubTarget(label: "18:00:00", seconds: 18 * 3600),
            ]),
        ],
    ]
}
