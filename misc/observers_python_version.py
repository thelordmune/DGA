"""
Python version of observers.luau
This is a reference implementation and not used in the actual codebase.
"""

from typing import TypeVar, Generic, Callable, Optional, Any, List, Dict
from dataclasses import dataclass

# Type variables
T = TypeVar('T')

# Type aliases
Entity = int
Id = int
World = Any
Archetype = Any


class Query(Generic[T]):
    """Query class for filtering entities"""
    def __init__(self):
        self.ids: List[Id] = []
        self.world: Optional[World] = None
        self.filter_with: Optional[List[Entity]] = None
        self.filter_without: Optional[List[Id]] = None
    
    def archetypes(self):
        """Iterator over matching archetypes"""
        pass


@dataclass
class Observer(Generic[T]):
    """Observer that watches for entity changes"""
    disconnect: Callable[[], None]


@dataclass
class Monitor(Generic[T]):
    """Monitor that tracks entity additions and removals"""
    disconnect: Callable[[], None]
    added: Callable[[Callable[[Entity], None]], None]
    removed: Callable[[Callable[[Entity], None]], None]


# Constants
ArchetypeCreate = "ArchetypeCreate"
ArchetypeDelete = "ArchetypeDelete"
Wildcard = -1


def IS_PAIR(term: int) -> bool:
    """Check if term is a pair"""
    return term < 0


def ECS_PAIR_FIRST(term: int) -> int:
    """Get first element of pair"""
    return abs(term) >> 16


def ECS_PAIR_SECOND(term: int) -> int:
    """Get second element of pair"""
    return abs(term) & 0xFFFF


def record(world: World, entity: Entity) -> Any:
    """Get entity record from world"""
    pass


def archetype_traverse_remove(world: World, id: Id, archetype: Archetype) -> Archetype:
    """Traverse archetype graph on removal"""
    pass


def get_matching_archetypes(world: World, query: Query) -> tuple[Dict[int, bool], Callable[[], None]]:
    """Get archetypes that match the query and return disconnect function"""
    archetypes: Dict[int, bool] = {}
    first = query.ids[0]
    
    for archetype in query.archetypes():
        archetypes[archetype.id] = True
    
    observable = world.observable
    on_create_action = observable.get(ArchetypeCreate)
    if not on_create_action:
        on_create_action = {}
        observable[ArchetypeCreate] = on_create_action
    
    query_cache_on_create = on_create_action.get(first)
    if not query_cache_on_create:
        query_cache_on_create = []
        on_create_action[first] = query_cache_on_create
    
    on_delete_action = observable.get(ArchetypeDelete)
    if not on_delete_action:
        on_delete_action = {}
        observable[ArchetypeDelete] = on_delete_action
    
    query_cache_on_delete = on_delete_action.get(first)
    if not query_cache_on_delete:
        query_cache_on_delete = []
        on_delete_action[first] = query_cache_on_delete
    
    def on_create_callback(archetype: Archetype):
        archetypes[archetype.id] = True
    
    def on_delete_callback(archetype: Archetype):
        if archetype.id in archetypes:
            del archetypes[archetype.id]
    
    observer_for_create = {"query": query, "callback": on_create_callback}
    observer_for_delete = {"query": query, "callback": on_delete_callback}
    
    query_cache_on_create.append(observer_for_create)
    query_cache_on_delete.append(observer_for_delete)
    
    def disconnect():
        if observer_for_create in query_cache_on_create:
            query_cache_on_create.remove(observer_for_create)
        if observer_for_delete in query_cache_on_delete:
            query_cache_on_delete.remove(observer_for_delete)
        archetypes.clear()
    
    return archetypes, disconnect


def observers_new(query: Query[T], callback: Callable[[Entity], None]) -> Observer[T]:
    """Create a new observer for the query"""
    world = query.world
    
    terms = query.ids
    with_filter = query.filter_with
    
    archetypes, disconnect_archetypes = get_matching_archetypes(world, query)
    
    def emplaced(entity: Entity):
        r = record(world, entity)
        archetype = r.archetype
        
        if archetypes.get(archetype.id):
            callback(entity)
    
    cleanup: List[Callable[[], None]] = []

    for term in terms:
        if IS_PAIR(term):
            rel = ECS_PAIR_FIRST(term)
            tgt = ECS_PAIR_SECOND(term)
            wc = tgt == Wildcard

            def on_changed_handler(entity: Entity, id: Id):
                if wc:
                    emplaced(entity)
                elif id == term:
                    emplaced(entity)

            onchanged = world.changed(rel, on_changed_handler)
            cleanup.append(onchanged)
        else:
            onchanged = world.changed(term, emplaced)
            cleanup.append(onchanged)

    if with_filter:
        for term in with_filter:
            if IS_PAIR(term):
                rel = ECS_PAIR_FIRST(term)
                tgt = ECS_PAIR_SECOND(term)
                wc = tgt == Wildcard

                def on_added_handler(entity: Entity, id: Id):
                    if wc:
                        emplaced(entity)
                    elif id == term:
                        emplaced(entity)

                onadded = world.added(rel, on_added_handler)
                cleanup.append(onadded)
            else:
                onadded = world.added(term, emplaced)
                cleanup.append(onadded)

    without_filter = query.filter_without
    if without_filter:
        for term in without_filter:
            if IS_PAIR(term):
                rel = ECS_PAIR_FIRST(term)

                def on_removed_handler(entity: Entity, id: Id):
                    r = record(world, entity)
                    archetype = r.archetype
                    dst = archetype_traverse_remove(world, id, archetype)

                    if archetypes.get(dst.id) and not archetypes.get(archetype.id):
                        callback(entity)

                onremoved = world.removed(rel, on_removed_handler)
                cleanup.append(onremoved)
            else:
                def on_removed_handler_simple(entity: Entity, id: Id):
                    r = record(world, entity)
                    archetype = r.archetype
                    dst = archetype_traverse_remove(world, id, archetype)
                    if archetypes.get(dst.id):
                        callback(entity)

                onremoved = world.removed(term, on_removed_handler_simple)
                cleanup.append(onremoved)

    def disconnect():
        disconnect_archetypes()
        for disconnect_fn in cleanup:
            disconnect_fn()

    observer = Observer(disconnect=disconnect)
    return observer


def monitors_new(query: Query[T]) -> Monitor[T]:
    """Create a new monitor for the query"""
    world = query.world
    archetypes, disconnect_archetypes = get_matching_archetypes(world, query)
    terms = query.filter_with or query.ids

    callback_added: Optional[Callable[[Entity], None]] = None
    callback_removed: Optional[Callable[[Entity], None]] = None

    def archetype_changed(entity: Entity, src: Archetype, dst: Archetype):
        if archetypes.get(dst.id):
            if not archetypes.get(src.id):
                if callback_added:
                    callback_added(entity)
        else:
            if archetypes.get(src.id):
                if callback_removed:
                    callback_removed(entity)

    cleanup: List[Callable[[], None]] = []

    for term in terms:
        if IS_PAIR(term):
            rel = ECS_PAIR_FIRST(term)

            def on_added_handler(entity: Entity, id: Id, _, src: Archetype):
                if callback_added is None:
                    return
                r = record(world, entity)
                dst = r and r.archetype

                if dst:
                    archetype_changed(entity, src, dst)

            def on_removed_handler(entity: Entity, id: Id):
                if callback_removed is None:
                    return
                r = record(world, entity)
                src = r and r.archetype
                dst = src and archetype_traverse_remove(world, id, src)
                if src:
                    archetype_changed(entity, src, dst)
                else:
                    callback_removed(entity)

            onadded = world.added(rel, on_added_handler)
            onremoved = world.removed(rel, on_removed_handler)
            cleanup.append(onadded)
            cleanup.append(onremoved)
        else:
            def on_added_handler_simple(entity: Entity, id: Id, _, src: Archetype):
                if callback_added is None:
                    return
                r = record(world, entity)
                dst = r and r.archetype

                if dst:
                    archetype_changed(entity, src, dst)

            def on_removed_handler_simple(entity: Entity):
                if callback_removed is None:
                    return
                r = record(world, entity)
                archetype = r and r.archetype

                if not archetype or archetypes.get(archetype.id):
                    callback_removed(entity)

            onadded = world.added(term, on_added_handler_simple)
            onremoved = world.removed(term, on_removed_handler_simple)
            cleanup.append(onadded)
            cleanup.append(onremoved)

    without_filter = query.filter_without
    if without_filter:
        for term in without_filter:
            if IS_PAIR(term):
                rel = ECS_PAIR_FIRST(term)

                def on_added_without_handler(entity: Entity, id: Id, _, src: Archetype):
                    if callback_removed is None:
                        return
                    r = record(world, entity)
                    dst = r.archetype

                    if dst:
                        archetype_changed(entity, src, dst)

                def on_removed_without_handler(entity: Entity, id: Id):
                    if callback_added is None:
                        return
                    r = record(world, entity)
                    src = r.archetype
                    dst = src and archetype_traverse_remove(world, id, src)
                    if dst:
                        archetype_changed(entity, src, dst)

                onadded = world.added(rel, on_added_without_handler)
                onremoved = world.removed(rel, on_removed_without_handler)
                cleanup.append(onadded)
                cleanup.append(onremoved)
            else:
                def on_added_without_simple(entity: Entity, id: Id, _, src: Archetype):
                    if callback_removed is None:
                        return

                    if archetypes.get(src.id):
                        callback_removed(entity)

                def on_removed_without_simple(entity: Entity, id: Id):
                    if callback_added is None:
                        return
                    r = record(world, entity)
                    src = r.archetype
                    dst = src and archetype_traverse_remove(world, id, src)
                    if dst:
                        archetype_changed(entity, src, dst)

                onadded = world.added(term, on_added_without_simple)
                onremoved = world.removed(term, on_removed_without_simple)
                cleanup.append(onadded)
                cleanup.append(onremoved)

    def disconnect():
        disconnect_archetypes()
        for disconnect_fn in cleanup:
            disconnect_fn()

    def monitor_added(callback: Callable[[Entity], None]):
        nonlocal callback_added
        callback_added = callback

    def monitor_removed(callback: Callable[[Entity], None]):
        nonlocal callback_removed
        callback_removed = callback

    monitor = Monitor(
        disconnect=disconnect,
        added=monitor_added,
        removed=monitor_removed
    )

    return monitor


# Export the main functions
__all__ = ['monitors_new', 'observers_new', 'Observer', 'Monitor', 'Query']

