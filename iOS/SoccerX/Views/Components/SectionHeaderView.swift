import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let action: SectionAction?
    
    init(title: String, action: SectionAction? = nil) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Spacer()
            
            if let action = action {
                Button(action: action.action) {
                    HStack(spacing: 4) {
                        Text(action.text)
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.7))
                    }
                }
            }
        }
    }
}

struct SectionAction {
    let text: String
    let action: () -> Void
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SectionHeaderView(title: "Recent Activity")
        
        SectionHeaderView(
            title: "This Week",
            action: SectionAction(text: "View All") {
                print("Navigate to all stats")
            }
        )
        
        SectionHeaderView(
            title: "Groups",
            action: SectionAction(text: "See More") {
                print("Navigate to groups")
            }
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}