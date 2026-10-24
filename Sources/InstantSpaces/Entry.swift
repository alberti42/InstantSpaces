import Foundation

@main
enum Entry {
    static func main() {
        CommandLineMode.runIfRequested(Array(CommandLine.arguments.dropFirst()))
        FileHandle.standardError.write(Data((CommandLineMode.usage + "\n").utf8))
    }
}
