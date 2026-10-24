import Foundation

@main
enum Entry {
    static func main() {
        CommandLineMode.runIfRequested(Array(CommandLine.arguments.dropFirst()))
        InstantSpacesApp.main()
    }
}
