#ifndef VISUAL_GASIC_LOADER_H
#define VISUAL_GASIC_LOADER_H

#include <godot_cpp/classes/resource_format_loader.hpp>
#include <godot_cpp/classes/resource_format_saver.hpp>

using namespace godot;

class VisualGasicFormatLoader : public ResourceFormatLoader {
	GDCLASS(VisualGasicFormatLoader, ResourceFormatLoader);

protected:
	static void _bind_methods() {}

public:
	virtual PackedStringArray _get_recognized_extensions() const override;
	virtual bool _handles_type(const StringName &p_type) const override;
	virtual String _get_resource_type(const String &p_path) const override;
	virtual Variant _load(const String &p_path, const String &p_original_path, bool p_use_sub_threads, int32_t p_cache_mode) const override;
};

class VisualGasicFormatSaver : public ResourceFormatSaver {
	GDCLASS(VisualGasicFormatSaver, ResourceFormatSaver);

protected:
	static void _bind_methods() {}

public:
	virtual PackedStringArray _get_recognized_extensions(const Ref<Resource> &p_resource) const override;
	virtual bool _recognize(const Ref<Resource> &p_resource) const override;
	virtual Error _save(const Ref<Resource> &p_resource, const String &p_path, uint32_t p_flags) override;
};


#endif // VISUAL_GASIC_LOADER_H
