package allocators

import "core:fmt"
import "core:mem"

Arena :: struct {
	memory: []byte,
	cur_offset: int,
}

init_arena :: proc(arena: ^Arena, backing: []byte) {
	assert(arena.memory == nil);
	arena^ = {};
	arena.memory = backing;
}

destroy_arena :: proc(arena: ^Arena) {
	delete(arena.memory);
	arena^ = {};
}

arena_allocator :: proc(arena: ^Arena) -> mem.Allocator {
	return mem.Allocator{arena_allocator_proc, arena};
}

arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                            size, alignment: int,
                            old_memory: rawptr, old_size: int,
                            flags: u64 = 0, loc := #caller_location) -> rawptr {

	arena := cast(^Arena)allocator_data;

	switch mode {
		case .Alloc: {
			// Don't allow allocations of zero size. This would likely return a
		    // pointer to a different allocation, causing many problems.
		    if size == 0 {
		        return nil;
		    }

		    // todo(josh): The `align_forward()` call and the `new_offset + size` below
		    // that could overflow if the `size` or `align` parameters are super huge

		    new_offset := mem.align_forward_int(arena.cur_offset, alignment);

		    // Don't allow allocations that would extend past the end of the arena.
		    if (new_offset + size) > len(arena.memory) {
		        return nil;
		    }

		    arena.cur_offset = new_offset + size;
		    ptr := &arena.memory[new_offset];
		    mem.zero(ptr, size);
		    return ptr;
		}
		case .Free: {
			return nil;
		}
		case .Free_All: {
			arena.cur_offset = 0;
			return nil;
		}
		case .Resize: {
			new_memory := arena_allocator_proc(allocator_data, .Alloc, size, alignment, old_memory, old_size, flags, loc);
			mem.copy(new_memory, old_memory, min(old_size, size));
			return new_memory;
		}
		case: panic(fmt.tprint(mode));
	}
	unreachable();
	return nil;
}