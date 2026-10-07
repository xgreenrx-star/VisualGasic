#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "templates/singly_linked_list.h"

using namespace godot;

static int passed = 0;
static int failed = 0;

static void check(bool condition, const char *description) {
	if (condition) {
		passed++;
	} else {
		failed++;
		UtilityFunctions::push_error(String("GDSION-POOL FAIL: ") + description);
	}
}

template <class T>
static void test_pool() {
	SinglyLinkedList<T> empty;
	check(empty.is_empty() && empty.get_front() == nullptr, "empty list");
	{
		SinglyLinkedList<T> unpooled(3, 4);
		unpooled.clear();
		check(unpooled.is_empty(), "clear without a pool");
	}
	SinglyLinkedList<T>::initialize_pool();
	SinglyLinkedList<T> ring(3, 7, true);
	auto *first = ring.get_front();
	auto *second = first->next();
	auto *third = second->next();
	ring.clear();
	check(ring.is_empty(), "clear a ring");
	SinglyLinkedList<T> reused(3, 9);
	check(reused.get_front() == first && first->next() == second && second->next() == third,
			"return every ring element exactly once to the pool");
	reused.clear();
	SinglyLinkedList<T> survivor(2, 11);
	SinglyLinkedList<T>::finalize_pool();
	survivor.clear();
	check(survivor.is_empty(), "clear a live list after pool finalization");
	SinglyLinkedList<T>::finalize_pool();
	check(empty.is_empty(), "pool finalization is idempotent");
	SinglyLinkedList<T>::initialize_pool();
	{
		SinglyLinkedList<T> restarted(2, 13);
		check(restarted.size() == 2 && restarted.get_front()->value == 13, "restart pool");
	}
	SinglyLinkedList<T>::finalize_pool();
}

static void initialize_pool_probe(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	test_pool<int>();
	test_pool<double>();
	UtilityFunctions::print("GDSION-POOL RESULTS: ", passed, " passed, ", failed, " failed");
}

extern "C" {
GDExtensionBool GDE_EXPORT gdsion_pool_probe_init(GDExtensionInterfaceGetProcAddress address,
		GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init(address, library, initialization);
	init.register_initializer(initialize_pool_probe);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}
}
