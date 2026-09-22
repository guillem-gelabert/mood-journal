import SwiftUI

struct ChartRangePicker: View {
    @Binding var range: ChartRange

    var body: some View {
        Picker("Range", selection: $range) {
            ForEach(ChartRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}
