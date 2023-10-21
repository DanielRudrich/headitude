//
//  OSCSender.swift
//  Headitude
//
//  Created by Daniel Rudrich on 08.10.23.
//

import CoreMotion
import OSCKit
import SwiftUI

struct OSCStorageType: Codable {
    var ip: String
    var port: UInt16
    var oscProtocol: String
}

class OSCSender {
    private var client = OSCClient()

    private var quaternion: CMQuaternion = .init()

    @AppStorage("oscSettings") var oscSettingsStore: Data = .init()

    @Published var oscProtocol = "/SceneRotator/ypr yaw pitch roll"
    @Published var ip = "localhost"
    @Published var port: UInt16 = 3001
    @Published var protocolValid = true

    init() {
        restoreSettings()
    }

    func restoreSettings() {
        guard let decoded = try? JSONDecoder().decode(OSCStorageType.self, from: oscSettingsStore) else { return }
        oscProtocol = decoded.oscProtocol
        ip = decoded.ip
        port = decoded.port
    }

    func storeSettings() {
        let oscSettingsData = OSCStorageType(ip: ip, port: port, oscProtocol: oscProtocol)
        guard let data = try? JSONEncoder().encode(oscSettingsData) else { return }
        oscSettingsStore = data
    }

    func setQuaternion(q: CMQuaternion) {
        quaternion = q.toAmbisonicCoordinateSystem()
        let taitBryan = quaternion.toTaitBryan()

        let protocolParts = oscProtocol.components(separatedBy: " ")
        let protocolPartsFiltered = protocolParts.filter { !$0.isEmpty }

        let address = protocolPartsFiltered[0]

        var values: OSCValues = []

        for i in 1 ..< protocolPartsFiltered.count {
            var part = protocolPartsFiltered[i]

            var factor: Float = 1.0

            if part.starts(with: "-") {
                factor = -1.0
                part = String(part.dropFirst())
            }

            var value: Float = 0.0

            switch part {
            case "yaw":
                value = Float(taitBryan.yaw * 180 / Double.pi)
            case "yaw+":
                value = Float(taitBryan.yaw * 180 / Double.pi)
                if value < 0 { value += 360 }
            case "pitch":
                value = Float(taitBryan.pitch * 180 / Double.pi)
            case "pitch+":
                value = Float(taitBryan.pitch * 180 / Double.pi)
                if value < 0 { value += 360 }
            case "roll":
                value = Float(taitBryan.roll * 180 / Double.pi)
            case "roll+":
                value = Float(taitBryan.roll * 180 / Double.pi)
                if value < 0 { value += 360 }

            case "qw":
                value = Float(quaternion.w)
            case "qx":
                value = Float(quaternion.x)
            case "qy":
                value = Float(quaternion.y)
            case "qz":
                value = Float(quaternion.z)

            default:
                protocolValid = false
                return
            }

            values.append(factor * value)
        }

        protocolValid = true

        let msg = OSCMessage(address, values: values)
        do {
            try client.send(msg, to: ip, port: port)
        } catch {
            print("failed osc")
        }
    }
}

struct OSCSenderView: View {
    @Binding var oscSender: OSCSender

    @Binding var isValid: Bool

    @State private var isIPPopoverVisible = false
    @State private var isMessagePopoverVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OSC Settings ").font(.system(size: 20, weight: .light)).foregroundStyle(Color(hex: 0xACACAC))
            HStack {
                HStack {
                    Text("Host / IP")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Button(action: {
                        isIPPopoverVisible.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to make the button look like an icon
                    .popover(isPresented: $isIPPopoverVisible, arrowEdge: .bottom) {
                        VStack {
                            Text("The IP-address or hostname of the OSC destination.")
                            Text("e.g. localhost or 127.0.0.1")
                        }.padding()
                    }

                    TextField("e.g., 127.0.0.1", text: $oscSender.ip)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack {
                    Text("Port")
                        .font(.headline)
                        .foregroundColor(.blue)
                    TextField("e.g., 8080", value: $oscSender.port, formatter: NumberFormatter.integer)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80)
                }
            }

            HStack {
                Text("Message")
                    .font(.headline)
                    .foregroundColor(.blue)
                Button(action: {
                    isMessagePopoverVisible.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to make the button look like an icon
                .popover(isPresented: $isMessagePopoverVisible, arrowEdge: .bottom) {
                    VStack {
                        Text("The OSC Message pattern, starting with an address and then space-delimited tokens.")
                        Text("e.g. /SceneRotator/ypr yaw pitch roll")
                    }.padding()
                }

                TextField("e.g., http://", text: $oscSender.oscProtocol)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .background(isValid ? Color.clear : Color.red)
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .background(Color(hex: 0x252525)).cornerRadius(8)
        .padding()
        .shadow(radius: 10)
    }
}

extension NumberFormatter {
    static var integer: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.thousandSeparator = ""
        return formatter
    }
}

struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
                .font(.system(size: 12))
        }
    }
}

#Preview {
    OSCSenderView(oscSender: .constant(OSCSender()), isValid: .constant(true)).frame(width: 400)
}
