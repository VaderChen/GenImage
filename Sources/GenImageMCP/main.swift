import GenImageMCPServer

@main
struct GenImageMCPMain {
    static func main() async {
        await MCPServer().runStdio()
    }
}
