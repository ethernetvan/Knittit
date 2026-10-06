//
//  CustomTabBar.swift
//  Knittit
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    enum TabItem: Int, CaseIterable {
        case feed = 0
        case scan = 1
        case profile = 2
        
        var title: String {
            switch self {
            case .feed: return "Feed"
            case .scan: return "Scan"
            case .profile: return "Profile"
            }
        }
        
        var iconName: String {
            switch self {
            case .feed: return "list.bullet"
            case .scan: return "viewfinder"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TabItem.allCases, id: \.rawValue) { tab in
                let isSelected = selectedTab == tab.rawValue
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab.rawValue
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected ? .blue : .primary)
                    .frame(minWidth: 80)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
}
