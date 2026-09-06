import ActorSystemDistributed
import Distributed

public distributed actor TypedCounter {
    public typealias ActorSystem = SwiftActorSystem

    public init(actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
    }

    public distributed func validate(_ value: Int) async throws(CounterError) -> Int {
        if value < 0 {
            throw .rejected(value)
        }
        return value
    }
}
