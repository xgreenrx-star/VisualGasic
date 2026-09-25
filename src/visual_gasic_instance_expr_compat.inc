// Shared AST/bytecode expr compat — from evaluate.inc Godot integration block
	if (method.nocasecmp_to("Load") == 0 && call_args.size() == 1) {
	     r_found = true; return ResourceLoader::get_singleton()->load(call_args[0]);
	}
	if (method.nocasecmp_to("LoadTexture") == 0 && call_args.size() == 1) {
	     r_found = true; return ResourceLoader::get_singleton()->load(call_args[0]);
	}
	if (method.nocasecmp_to("LoadTexture3D") == 0 && call_args.size() == 1) {
	     r_found = true; return ResourceLoader::get_singleton()->load(call_args[0]);
	}
	if (method.nocasecmp_to("LoadSprite") == 0 && call_args.size() == 1) {
	     r_found = true;
	     Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(call_args[0]);
	     if (tex.is_valid()) {
	          Sprite2D *s = memnew(Sprite2D);
	          s->set_texture(tex);
	          r_found = true; return s;
	     }
	     r_found = true; return Variant(); 
	}

	if (method == "CreateMSComm") {
	     MSComm *comm = memnew(MSComm);
	     // MSComm is now RefCounted, so we don't add to tree.
	     // It is managed by the variable (Variant) holding the Ref.
	     r_found = true; return Ref<MSComm>(comm);
	}

	if (method == "CreateSprite" && call_args.size() == 1) {
	     Variant arg = call_args[0];
	     Ref<Texture2D> tex = arg;
	     Sprite2D *s = memnew(Sprite2D);
	     if (tex.is_valid()) s->set_texture(tex);
	     r_found = true; return s;
	}

	if (method == "CreateProgressBar") {
	     ProgressBar *pb = memnew(ProgressBar);
	     if (call_args.size() >= 1) pb->set_min(call_args[0]);
	     if (call_args.size() >= 2) pb->set_max(call_args[1]);
	     if (call_args.size() >= 3) pb->set_value(call_args[2]);
	     
	     // Optional Position
	     if (call_args.size() >= 5) {
	         pb->set_position(Vector2(call_args[3], call_args[4]));
	         pb->set_size(Vector2(200, 20)); // Default size
	     } else {
	         pb->set_size(Vector2(200, 20));
	         pb->set_position(Vector2(50, 50));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(pb);
	              dynamic_nodes.push_back(pb->get_instance_id());
	         }
	     }
	     r_found = true; return pb;
	}

	if (method == "CreateSlider") {
	     HSlider *s = memnew(HSlider);
	     if (call_args.size() >= 1) s->set_min(call_args[0]);
	     if (call_args.size() >= 2) s->set_max(call_args[1]);
	     if (call_args.size() >= 3) s->set_value(call_args[2]);
	     
	     if (call_args.size() >= 5) {
	         s->set_position(Vector2(call_args[3], call_args[4]));
	         s->set_size(Vector2(200, 20));
	     } else {
	         s->set_size(Vector2(200, 20));
	         s->set_position(Vector2(50, 100));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(s);
	              dynamic_nodes.push_back(s->get_instance_id());
	         }
	     }
	     r_found = true; return s;
	}

	if (method == "CreateListView") {
	     ItemList *il = memnew(ItemList);
	     
	     if (call_args.size() >= 2) {
	         il->set_position(Vector2(call_args[0], call_args[1]));
	         il->set_size(Vector2(200, 150));
	     } else {
	         il->set_position(Vector2(50, 150));
	         il->set_size(Vector2(200, 150));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(il);
	              dynamic_nodes.push_back(il->get_instance_id());
	         }
	     }
	     r_found = true; return il;
	}

	if (method == "CreateFlexGrid") {
	     int rows = 2;
	     int cols = 2;
	     if (call_args.size() >= 1) rows = call_args[0];
	     if (call_args.size() >= 2) cols = call_args[1];
	     
	     Tree *t = memnew(Tree);
	     t->set_columns(cols);
	     t->set_column_titles_visible(true);
	     t->set_select_mode(Tree::SELECT_SINGLE);
	     
	     // Create Root (Hidden usually in FlexGrid context, but Tree needs one)
	     TreeItem *root = t->create_item();
	     
	     // Create Rows
	     for(int i=0; i<rows; i++) {
	         TreeItem *it = t->create_item(root);
	         // Initialize text?
	     }
	     
	     if (call_args.size() >= 4) {
	         t->set_position(Vector2(call_args[2], call_args[3]));
	         t->set_size(Vector2(300, 200));
	     } else {
	         t->set_position(Vector2(50, 200));
	         t->set_size(Vector2(300, 200));
	     }
	     
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(t);
	              dynamic_nodes.push_back(t->get_instance_id());
	         }
	     }
	     r_found = true; return t;
	}



	if (method == "CreateText" && call_args.size() >= 1) {
	     String text = call_args[0];
	     Label *l = memnew(Label);
	     l->set_text(text);
	     if (call_args.size() >= 3) {
	         l->set_position(Vector2(call_args[1], call_args[2]));
	     }
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(l);
	              dynamic_nodes.push_back(l->get_instance_id());
	         }
	     }
	     r_found = true; return l;
	}

	if (method.nocasecmp_to("GetAxis") == 0 && call_args.size() == 2) {
	     String neg = call_args[0];
	     String pos = call_args[1];
	     r_found = true; return Input::get_singleton()->get_axis(neg, pos);
	}

	if (method.nocasecmp_to("GetJoyAxis") == 0 && call_args.size() == 2) {
	     int device = call_args[0];
	     int axis = call_args[1];
	     r_found = true; return Input::get_singleton()->get_joy_axis(device, (JoyAxis)axis);
	}

	if (method == "CreateParticles2D" && call_args.size() >= 1) {
	     Variant arg = call_args[0];
	     Ref<Material> mat;
	     if (arg.get_type() == Variant::STRING) {
	         mat = ResourceLoader::get_singleton()->load(arg);
	     } else if (arg.get_type() == Variant::OBJECT) {
	         mat = arg;
	     }

	     GPUParticles2D *p = memnew(GPUParticles2D);
	     if (mat.is_valid()) p->set_process_material(mat);
	     p->set_emitting(true); // Auto start

	     if (call_args.size() >= 3) {
	         p->set_position(Vector2(call_args[1], call_args[2]));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(p);
	              dynamic_nodes.push_back(p->get_instance_id());
	         }
	     }
	     r_found = true; return p;
	}

	if (method == "CreateParticles3D" && call_args.size() >= 1) {
	     Variant arg = call_args[0];
	     Ref<Material> mat;
	     if (arg.get_type() == Variant::STRING) {
	         mat = ResourceLoader::get_singleton()->load(arg);
	     } else if (arg.get_type() == Variant::OBJECT) {
	         mat = arg;
	     }

	     GPUParticles3D *p = memnew(GPUParticles3D);
	     if (mat.is_valid()) p->set_process_material(mat);
	     p->set_emitting(true); // Auto start

	     if (call_args.size() >= 4) {
	         p->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(p);
	              dynamic_nodes.push_back(p->get_instance_id());
	         }
	     }
	     r_found = true; return p;
	}

	if (method == "CreateMultiMeshInstance3D" && call_args.size() >= 1) {
	     Variant arg = call_args[0];
	     Ref<MultiMesh> mesh;
	     if (arg.get_type() == Variant::STRING) {
	         mesh = ResourceLoader::get_singleton()->load(arg);
	     } else if (arg.get_type() == Variant::OBJECT) {
	         mesh = arg;
	     }
	     
	     MultiMeshInstance3D *m = memnew(MultiMeshInstance3D);
	     if (mesh.is_valid()) m->set_multimesh(mesh);
	     
	     if (call_args.size() >= 4) {
	         m->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(m);
	              dynamic_nodes.push_back(m->get_instance_id());
	         }
	     }
	     r_found = true; return m;
	}

	if (method == "CreateTextureRect" && call_args.size() >= 1) {
	     Variant arg = call_args[0];
	     Ref<Texture2D> tex;
	     if (arg.get_type() == Variant::STRING) {
	         tex = ResourceLoader::get_singleton()->load(arg);
	     } else if (arg.get_type() == Variant::OBJECT) {
	         tex = arg;
	     }
	     
	     TextureRect *tr = memnew(TextureRect);
	     if (tex.is_valid()) tr->set_texture(tex);
	     
	     if (call_args.size() >= 3) {
	         tr->set_position(Vector2(call_args[1], call_args[2]));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(tr);
	              dynamic_nodes.push_back(tr->get_instance_id());
	         }
	     }
	     r_found = true; return tr;
	}

	if (method == "CreateSprite3D" && call_args.size() >= 1) {
	     Variant arg = call_args[0];
	     Ref<Texture2D> tex;
	     if (arg.get_type() == Variant::STRING) {
	         tex = ResourceLoader::get_singleton()->load(arg);
	     } else if (arg.get_type() == Variant::OBJECT) {
	         tex = arg;
	     }
	     
	     Sprite3D *s = memnew(Sprite3D);
	     if (tex.is_valid()) s->set_texture(tex);
	     
	     if (call_args.size() >= 4) {
	         s->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(s);
	              dynamic_nodes.push_back(s->get_instance_id());
	         }
	     }
	     r_found = true; return s;
	}

	if (method == "CreateNode" && call_args.size() == 1) {
	     String type = call_args[0];
	     if (ClassDB::class_exists(type) && ClassDB::can_instantiate(type)) {
	          Variant res = ClassDB::instantiate(type);
	          r_found = true; return res;
	     }
	     r_found = true; return Variant();
	}
	if (method == "AddChild" && call_args.size() == 1) {
	     Object *obj = call_args[0];
	     Node *child = Object::cast_to<Node>(obj);
	     if (child && owner && child->get_parent() == nullptr) {
	          Node *parent = Object::cast_to<Node>(owner);
	          if (parent) {
	               parent->add_child(child);
	          }
	     }
	     r_found = true; return Variant();
	}

	if (method == "Instantiate" && call_args.size() == 1) {
	     // Supports path or PackedScene
	     Variant arg = call_args[0];
	     Ref<PackedScene> scene;
	     if (arg.get_type() == Variant::STRING) {
	          scene = ResourceLoader::get_singleton()->load(arg);
	     } else if (arg.get_type() == Variant::OBJECT) {
	          scene = arg;
	     }
	     
	     if (scene.is_valid()) {
	          r_found = true; return scene->instantiate();
	     }
	     r_found = true; return Variant(); 
	}

	if (method == "LoadShader" && call_args.size() == 1) {
	     r_found = true; return ResourceLoader::get_singleton()->load(call_args[0]);
	}
	
	if (method == "CompileShader" && call_args.size() == 1) {
	     String code = call_args[0];
	     Ref<Shader> shader;
	     shader.instantiate();
	     shader->set_code(code);
	     r_found = true; return shader;
	}
	
	if (method == "GetDelta" && call_args.size() == 0) {
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) return n->get_process_delta_time();
	     }
	     r_found = true; return 0.0;
	}

	// Input Handling
	if (method == "IsActionPressed" && call_args.size() == 1) {
	    String action = call_args[0];
	    r_found = true; return Input::get_singleton()->is_action_pressed(action);
	}
	if (method == "IsActionJustPressed" && call_args.size() == 1) {
	    String action = call_args[0];
	    r_found = true; return Input::get_singleton()->is_action_just_pressed(action);
	}
	if (method == "IsActionJustReleased" && call_args.size() == 1) {
	    String action = call_args[0];
	    r_found = true; return Input::get_singleton()->is_action_just_released(action);
	}
	if (method == "IsKeyPressed" && call_args.size() == 1) {
	    int key = call_args[0];
	    r_found = true; return Input::get_singleton()->is_key_pressed((Key)key);
	}
	if (method == "IsKeyJustPressed" && call_args.size() == 1) {
	    int key = call_args[0];
	    r_found = true; return VGInputEdge::is_key_just_pressed((Key)key);
	}
	if (method == "IsKeyJustReleased" && call_args.size() == 1) {
	    int key = call_args[0];
	    r_found = true; return VGInputEdge::is_key_just_released((Key)key);
	}
	if (method == "IsMouseButtonPressed" && call_args.size() == 1) {
	    int btn = call_args[0];
	    r_found = true; return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
	}
	if (method == "GetMousePosition" && call_args.size() == 0) {
	     r_found = true;
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              Viewport *vp = n->get_viewport();
	              if (vp) return vp->get_mouse_position();
	         }
	     }
	     return DisplayServer::get_singleton()->mouse_get_position();
	}
	
	// Factory for Vector2
	if (method.nocasecmp_to("Vector2") == 0 && call_args.size() == 2) {
	     r_found = true; return Vector2(call_args[0], call_args[1]);
	}

	if (method.nocasecmp_to("TweenProperty") == 0 && call_args.size() == 4) {
	     Object *obj = call_args[0];
	     String prop = call_args[1];
	     Variant final_val = call_args[2];
	     double duration = call_args[3];
	     
	     if (obj && owner) {
	          Node *n = Object::cast_to<Node>(owner);
	          if (n) {
	               Ref<Tween> t = n->create_tween();
	               t->tween_property(obj, NodePath(prop), final_val, duration);
	               r_found = true; return t;
	          }
	     }
	     r_found = true; return Variant();
	}

	if (method == "CreateFileDialog" || method == "CreateCommonDialog") {
	     FileDialog *fd = memnew(FileDialog);
	     fd->set_access(FileDialog::ACCESS_FILESYSTEM); 
	     fd->set_file_mode(FileDialog::FILE_MODE_OPEN_FILE);
	     fd->set_size(Vector2(600, 400));
	     fd->set_title("Open File");
	     
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	              n->add_child(fd);
	              dynamic_nodes.push_back(fd->get_instance_id());
	              fd->call_deferred("popup_centered");
	         }
	     }
	     r_found = true; return fd;
	}

	if (method == "HasCollided" && call_args.size() == 1) {
	     Object *obj = call_args[0];
	     CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
	     if (cb2d) {
	         r_found = true; return cb2d->get_slide_collision_count() > 0;
	     }
	     CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
	     if (cb3d) {
	         r_found = true; return cb3d->get_slide_collision_count() > 0;
	     }
	     r_found = true; return false;
	}

	if (method == "GetCollider" && call_args.size() == 1) {
	     Object *obj = call_args[0];
	     CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
	     if (cb2d && cb2d->get_slide_collision_count() > 0) {
	         Ref<KinematicCollision2D> col = cb2d->get_slide_collision(0);
	         if (col.is_valid()) return col->get_collider();
	     }
	     CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
	     if (cb3d && cb3d->get_slide_collision_count() > 0) {
	         Ref<KinematicCollision3D> col = cb3d->get_slide_collision(0);
	         if (col.is_valid()) return col->get_collider();
	     }
	     r_found = true; return Variant();
	}

	if (method == "CreateTrigger" && call_args.size() >= 4) {
	     String name = call_args[0];
	     double x = call_args[1];
	     double y = call_args[2];
	     double w = call_args[3];
	     double h = (call_args.size() > 4) ? (double)call_args[4] : w;
	     
	     Area2D *area = memnew(Area2D);
	     area->set_name(name);
	     area->set_position(Vector2(x,y));
	     
	     CollisionShape2D *shape = memnew(CollisionShape2D);
	     Ref<RectangleShape2D> rect;
	     rect.instantiate();
	     rect->set_size(Vector2(w, h));
	     shape->set_shape(rect);
	     area->add_child(shape);
	     
	     if (owner) {
	          Node *n = Object::cast_to<Node>(owner);
	          if (n) {
	              n->add_child(area);
	              dynamic_nodes.push_back(area->get_instance_id());
	              area->connect("body_entered", Callable(owner, "_OnSignal").bind(name, "Collision"));
	          }
	     }
	     r_found = true; return area;
	}

	if (method == "CreateTimer" && call_args.size() >= 1) {
	     double interval = call_args[0]; // in seconds
	     bool active = true;
	     if (call_args.size() >= 2) active = call_args[1];
	     
	     Timer *t = memnew(Timer);
	     t->set_wait_time(interval);
	     t->set_autostart(active);
	     t->set_one_shot(false);
	     
	     // Name? "Timer"+ID
	     // We need a stable name/ID for the event binding if arguments don't provide it.
	     // VB6 Timers were controls drawn on form with a name.
	     // Here, CreateTimer needs to return the object so we can stop it.
	     // But to hook up events.. "Sub MyTimer_Timer()"?
	     // We need to know the variable name assigned to? We don't know that here.
	     // User should probably Set Name property? 
	     // Or allow CreateTimer("Name", Interval)
	     
	     String name = "TimerVal"; 
	     if (call_args.size() == 3) name = call_args[3]; // Not ideal arg order
	     
	     // Better: Allow binding later via name set? 
	     // Or assume user passes name as first arg: CreateTimer("MyTimer", 1000)
	     
	     if (call_args[0].get_type() == Variant::STRING) {
	          name = call_args[0];
	          interval = call_args[1];
	          if (call_args.size() >= 3) active = call_args[2];
	          t->set_wait_time(interval);
	          t->set_name(name);
	     } else {
	          // Anonymous timer? Hard to bind events.
	     }

	     if (owner) {
	          Node *n = Object::cast_to<Node>(owner);
	          if (n) {
	              n->add_child(t);
	              dynamic_nodes.push_back(t->get_instance_id());
	              // Bind timeout
	              t->connect("timeout", Callable(owner, "_OnSignal").bind(name, "Timer"));
	              // Autostart handles it if in tree. If not, autostart=true will start it when it enters.
	              // No need to call start() manually.
	          }
	     }
	     r_found = true; return t;
	}
	
	if (method == "CreateMenu" && call_args.size() >= 1) {
	     String title = call_args[0];
	     String name = title; // Default name matches title
	     if (call_args.size() >= 2) name = call_args[1];

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         CanvasItem *ci = Object::cast_to<CanvasItem>(n);
	         if (ci) {
	             // Find or Create MenuBar container
	             Node *menu_bar = n->find_child("VisualGasicMenuBar", false, false);
	             HBoxContainer *hbox = nullptr;
	             
	             if (!menu_bar) {
	                 hbox = memnew(HBoxContainer);
	                 hbox->set_name("VisualGasicMenuBar");
	                 hbox->set_position(Vector2(0,0));
	                 hbox->set_size(Vector2(1024, 30)); // Stretch later?
	                 // Ideally anchored top
	                 hbox->set_anchors_and_offsets_preset(Control::PRESET_TOP_WIDE);
	                 n->add_child(hbox);
	             } else {
	                 hbox = Object::cast_to<HBoxContainer>(menu_bar);
	             }
	             
	             if (hbox) {
	                 MenuButton *mb = memnew(MenuButton);
	                 mb->set_text(title);
	                 mb->set_name(name);
	                 mb->set_switch_on_hover(true);
	                 hbox->add_child(mb);
	                 
	                 dynamic_nodes.push_back(mb->get_instance_id());
	                 
	                 // Return the PopupMenu so we can add items
	                 r_found = true; return mb->get_popup();
	             }
	         }
	     }
	     r_found = true; return Variant();
	}

	if (method == "CreateActor2D" && call_args.size() >= 3) {
	     String img_path = call_args[0];
	     double x = call_args[1];
	     double y = call_args[2];
	     
	     CharacterBody2D *body = memnew(CharacterBody2D);
	     body->set_position(Vector2(x, y));
	     
	     // Sprite
	     Sprite2D *sprite = memnew(Sprite2D);
	     Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(img_path);
	     if (tex.is_valid()) {
	         sprite->set_texture(tex);
	         // Collision Shape (Circle based on texture size approx)
	         CollisionShape2D *shape = memnew(CollisionShape2D);
	         Ref<CircleShape2D> circle;
	         circle.instantiate();
	         float radius = tex->get_width() / 2.0;
	         circle->set_radius(radius);
	         shape->set_shape(circle);
	         body->add_child(shape);
	     } else {
	         // Fallback Shape
	         CollisionShape2D *shape = memnew(CollisionShape2D);
	         Ref<CircleShape2D> circle;
	         circle.instantiate();
	         circle->set_radius(20.0);
	         shape->set_shape(circle);
	         body->add_child(shape);
	     }
	     body->add_child(sprite);
	     
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	             n->add_child(body);
	             dynamic_nodes.push_back(body->get_instance_id());
	         }
	     }
	     r_found = true; return body;
	}
	
	if (method == "CreateText" && call_args.size() >= 1) {
	     String text = call_args[0];
	     Label *l = memnew(Label);
	     l->set_text(text);
	     if (call_args.size() >= 2) {
	          // Only if vector?
	          if (call_args.size() == 2 && call_args[1].get_type() == Variant::VECTOR2) {
	               l->set_position(call_args[1]);
	          } else if (call_args.size() >= 3) {
	               l->set_position(Vector2(call_args[1], call_args[2]));
	          }
	     }
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	             n->add_child(l);
	             dynamic_nodes.push_back(l->get_instance_id());
	         }
	     }
	     r_found = true; return l;
	}

	// --- NEW PRO FEATURES ---
	if (method.nocasecmp_to("CreateLabel") == 0 && call_args.size() >= 3) {
	    String text = call_args[0];
	    double x = call_args[1]; 
	    double y = call_args[2];
	    
	    Label *l = memnew(Label);
	    l->set_text(text);
	    l->set_position(Vector2(x,y));
	    
	    if (owner) {
	        Node *n = Object::cast_to<Node>(owner);
	        if (n) {
	            n->add_child(l);
	            dynamic_nodes.push_back(l->get_instance_id());
	        }
	    }
	    r_found = true; return l;
	}

	if (method.nocasecmp_to("CreateButton") == 0 && call_args.size() >= 3) {
	     String text = call_args[0];
	     double x = call_args[1];
	     double y = call_args[2];
	     
	     Button *b = memnew(Button);
	     b->set_text(text);
	     b->set_position(Vector2(x, y));
	     
	     if (call_args.size() >= 4) {
	         // Callback Name
	         String callback = call_args[3];
	         // Bind "pressed" to _OnSignal (which calls BASIC sub)
	         b->connect("pressed", Callable(owner, "_OnSignal").bind(callback, ""));
	     }

	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	             n->add_child(b);
	             dynamic_nodes.push_back(b->get_instance_id());
	         }
	     }
	     r_found = true; return b;
	}

	if (method.nocasecmp_to("CreateInput") == 0 && call_args.size() >= 3) {
	     String text = call_args[0];
	     double x = call_args[1];
	     double y = call_args[2];
	     
	     LineEdit *le = memnew(LineEdit);
	     le->set_text(text);
	     le->set_position(Vector2(x,y));
	     
	     if (call_args.size() >= 4) {
	         double width = call_args[3];
	         le->set_size(Vector2(width, le->get_size().y));
	     } else {
	         le->set_size(Vector2(100, le->get_size().y));
	     }
	     
	     if (owner) {
	         Node *n = Object::cast_to<Node>(owner);
	         if (n) {
	             n->add_child(le);
	             dynamic_nodes.push_back(le->get_instance_id());
	         }
	     }
	     r_found = true; return le;
	}

	if (method.nocasecmp_to("GetKey") == 0 && call_args.size() == 1) {
	    Key key = Key::KEY_NONE;
	    if (call_args[0].get_type() == Variant::INT || call_args[0].get_type() == Variant::FLOAT) {
	        key = (Key)(int)call_args[0];
	    } else {
	        String k = call_args[0];
	        key = (Key)OS::get_singleton()->find_keycode_from_string(k);
	    }
	    r_found = true; return Input::get_singleton()->is_key_pressed(key);
	}
	if (method.nocasecmp_to("IsKeyDown") == 0 && call_args.size() == 1) {
	    Key key = Key::KEY_NONE;
	    if (call_args[0].get_type() == Variant::INT || call_args[0].get_type() == Variant::FLOAT) {
	        key = (Key)(int)call_args[0];
	    } else {
	        String k = call_args[0];
	        key = (Key)OS::get_singleton()->find_keycode_from_string(k);
	    }
	    r_found = true; return Input::get_singleton()->is_key_pressed(key);
	}
	if (method.nocasecmp_to("IsMouseButtonDown") == 0 && call_args.size() == 1) {
	    int btn = call_args[0];
	    r_found = true; return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
	}
	if (method.nocasecmp_to("GetMouseX") == 0) {
	    r_found = true;
	    if (owner) {
	        Node *n = Object::cast_to<Node>(owner);
	        if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().x;
	    }
	    return 0.0;
	}
	if (method.nocasecmp_to("GetMouseY") == 0) {
	    r_found = true;
	    if (owner) {
	        Node *n = Object::cast_to<Node>(owner);
	        if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().y;
	    }
	    return 0.0;
	}

	if (method.nocasecmp_to("IsOnFloor") == 0 && call_args.size() == 1) {
	    Object *o = call_args[0];
	    CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
	    if (cb2) return cb2->is_on_floor();
	    CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
	    if (cb3) return cb3->is_on_floor();
	    r_found = true; return false;
	}
	if (method.nocasecmp_to("GetCollisionCount") == 0 && call_args.size() == 1) {
	    Object *o = call_args[0];
	    CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
	    if (cb2) return cb2->get_slide_collision_count();
	    CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
	    if (cb3) return cb3->get_slide_collision_count();
	    r_found = true; return 0;
	}

	if (method == "GetAxis" && call_args.size() == 2) {
	     r_found = true; return Input::get_singleton()->get_axis(call_args[0], call_args[1]);
	}
	
	if (method == "GetJoyAxis" && call_args.size() == 2) {
	     r_found = true; return Input::get_singleton()->get_joy_axis(call_args[0], (JoyAxis)(int)call_args[1]);
	}

	if (method == "GetMousePos" && call_args.size() == 0) {
	     // Return global or viewport position?
	     // Viewport makes most sense for Canvas
	     // But we need a node context.
	     r_found = true;
	     if (owner) {
	          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
	          // Check viewport availability to prevent crashes in headless/unititialized state
	          if (ci && ci->get_viewport()) return ci->get_local_mouse_position();
	          
	          Node *n = Object::cast_to<Node>(owner);
	          if (n) {
	               Viewport *vp = n->get_viewport();
	               if (vp) return vp->get_mouse_position();
	          }
	     }
	     return Vector2(0,0);
	}
	if (method == "GetGlobalMousePos" && call_args.size() == 0) {
	     r_found = true;
	     if (owner) {
	          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
	          if (ci && ci->get_viewport()) return ci->get_global_mouse_position();
	     }
	     // Or display server
	     return DisplayServer::get_singleton()->mouse_get_position(); 
	}
	
	// ============================================
	// Game-Specific Keyword Functions
	// ============================================
	
	// Whenever system functions
	if (method.nocasecmp_to("ActiveWheneverCount") == 0 && call_args.size() == 0) {
	    r_found = true; return get_active_whenever_count();
	}
	if (method.nocasecmp_to("WheneverStatus") == 0 && call_args.size() == 0) {
	    r_found = true; return get_whenever_status();
	}
	
	// Keyboard input functions. INKEY$ / Point(x, y) read the QB screen buffer.
	if ((method.nocasecmp_to("Inkey") == 0 || method.nocasecmp_to("Inkey$") == 0) && call_args.size() == 0) {
	    Variant qb_ret;
	    bool qb_handled = false;
	    if (VGQbScreen::handle_expr(this, method, call_args, qb_ret, qb_handled) && qb_handled) {
	        r_found = true;
	        return qb_ret;
	    }
	    r_found = true; return String("");
	}
	if (method.nocasecmp_to("Point") == 0 && call_args.size() == 2) {
	    Variant qb_ret;
	    bool qb_handled = false;
	    if (VGQbScreen::handle_expr(this, method, call_args, qb_ret, qb_handled) && qb_handled) {
	        r_found = true;
	        return qb_ret;
	    }
	}
	
	// Mouse input functions
	if (method.nocasecmp_to("MouseClick") == 0 && call_args.size() == 0) {
	    // Return mouse button state as bitmask
	    int state = 0;
	    if (Input::get_singleton()->is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) state |= 1;
	    if (Input::get_singleton()->is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) state |= 2;
	    if (Input::get_singleton()->is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) state |= 4;
	    r_found = true; return state;
	}
	if (method.nocasecmp_to("MouseX") == 0 && call_args.size() == 0) {
	    r_found = true;
	    if (owner) {
	        Node *n = Object::cast_to<Node>(owner);
	        if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().x;
	    }
	    return 0.0;
	}
	if (method.nocasecmp_to("MouseY") == 0 && call_args.size() == 0) {
	    r_found = true;
	    if (owner) {
	        Node *n = Object::cast_to<Node>(owner);
	        if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().y;
	    }
	    return 0.0;
	}

