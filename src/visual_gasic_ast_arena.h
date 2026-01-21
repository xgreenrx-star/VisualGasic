#ifndef VISUAL_GASIC_AST_ARENA_H
#define VISUAL_GASIC_AST_ARENA_H

// Lightweight arena allocator for AST nodes.
// Current implementation is a simple placeholder that can be
// expanded later. It provides bulk allocation semantics and
// an efficient clear() to free all allocated blocks at once.

#include <vector>
#include <cstddef>

class ASTArena {
public:
    ASTArena() {}
    ~ASTArena() { clear(); }

    // Allocate raw bytes (caller placement-news into returned pointer).
    void* allocate_bytes(std::size_t sz) {
        void* p = ::operator new(sz);
        blocks.push_back(p);
        return p;
    }

    // Convenience template to allocate and construct an object of type T
    template<typename T, typename... Args>
    T* alloc(Args&&... args) {
        void* mem = allocate_bytes(sizeof(T));
        return new (mem) T(std::forward<Args>(args)...);
    }

    // Free all allocations (calls destructors then frees memory)
    void clear() {
        for (void* p : blocks) {
            ::operator delete(p);
        }
        blocks.clear();
    }

private:
    std::vector<void*> blocks;
};

#endif // VISUAL_GASIC_AST_ARENA_H
