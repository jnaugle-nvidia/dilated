import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack {
            Image(systemName: "eye")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Dilated")
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
