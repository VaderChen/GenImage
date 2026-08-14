import Foundation
import GenImageMCPServer
import Testing

struct MCPServerTests {
    @Test func initializeNegotiatesStandardProtocol() async throws {
        let response = await MCPServer().handle(
            request: [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": ["protocolVersion": "2025-06-18"]
            ]
        )
        let result = response?["result"] as? [String: Any]

        #expect(result?["protocolVersion"] as? String == "2025-06-18")
        #expect(result?["serverInfo"] != nil)
    }

    @Test func toolsListExposesStableGenImageTools() async throws {
        let response = await MCPServer().handle(
            request: [
                "jsonrpc": "2.0",
                "id": "tools",
                "method": "tools/list"
            ]
        )
        let result = response?["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]] ?? []
        let names = Set(tools.compactMap { $0["name"] as? String })

        #expect(names.contains("genimage_models_list"))
        #expect(names.contains("genimage_profiles_list"))
        #expect(names.contains("genimage_upscale_image"))
        #expect(names.contains("genimage_generate_image"))
        #expect(names.contains("genimage_describe_image"))
    }

    @Test func unknownMethodsReturnJSONRPCError() async throws {
        let response = await MCPServer().handle(
            request: [
                "jsonrpc": "2.0",
                "id": 3,
                "method": "missing/method"
            ]
        )
        let error = response?["error"] as? [String: Any]

        #expect(error?["code"] as? Int == -32601)
    }
}
