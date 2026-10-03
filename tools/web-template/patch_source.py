import pathlib, hashlib, json, difflib, zipfile
ROOT=pathlib.Path(__file__).resolve().parent
SRC=ROOT/'godot'
FILES=['drivers/gles3/shader_gles3.h','drivers/gles3/shader_gles3.cpp','servers/rendering/rendering_server.h','servers/rendering/rendering_server.cpp','platform/web/detect.py']
with zipfile.ZipFile(ROOT/'godot-official.zip') as archive:
    prefix=archive.namelist()[0].split('/')[0]+'/'
    original={p:archive.read(prefix+p).decode('utf-8') for p in FILES}
for p,content in original.items():
    (SRC/p).write_text(content,encoding='utf-8',newline='\n')
def replace(path, old, new):
    f=SRC/path
    s=f.read_text(encoding='utf-8')
    assert s.count(old)==1, (path, old[:90],s.count(old))
    f.write_text(s.replace(old,new),encoding='utf-8',newline='\n')

H=FILES[0]; C=FILES[1]; RH=FILES[2]; RC=FILES[3]
replace(H, '#include "core/templates/rid_owner.h"', '#include "core/templates/rid_owner.h"\n#include "core/variant/dictionary.h"')
replace(H,'\tvoid _clear_version(Version *p_version);', '''#ifdef WEB_ENABLED
	struct WebPending {
		ShaderGLES3 *shader = nullptr;
		Version *version = nullptr;
		uint32_t variant = 0;
		uint64_t specialization = 0;
	};
	static LocalVector<WebPending> web_pending;
	static bool web_extension_checked;
	static bool web_parallel_supported;
	static uint64_t web_submitted;
	static uint64_t web_completed;
	static uint64_t web_failed;
	static uint64_t web_cancelled;
	static uint64_t web_skipped_binds;
	static Vector<String> web_errors;
	bool web_scene_shader = false;
	void _submit_web_specialization(Version::Specialization &spec, uint32_t p_variant, Version *p_version, uint64_t p_specialization);
	void _finish_web_specialization(Version::Specialization &spec, Version *p_version);
	static void _poll_web_specializations();
#endif
	void _clear_version(Version *p_version);''')
replace(H, '\t\tVersion::Specialization *spec = version->variants[p_variant].getptr(p_specialization);\n\t\tif (!spec) {', '''#ifdef WEB_ENABLED
		_poll_web_specializations();
#endif
		Version::Specialization *spec = version->variants[p_variant].getptr(p_specialization);
		if (!spec) {''')
replace(H, '''		} else if (spec->build_queued) {
			// Still queued, wait
			spec = version->variants[p_variant].getptr(specialization_default_mask);
		}

		if (!spec || !spec->ok) {''', '''		}
#ifdef WEB_ENABLED
		if (spec && spec->build_queued) {
			// The caller skips this draw while the loading overlay remains visible.
			// Never bind another specialization with mismatched uniforms/features.
			web_skipped_binds++;
			return false;
		}
#endif
		if (!spec || !spec->ok) {''')
replace(H, 'public:\n\tRID version_create();', 'public:\n\tstatic Dictionary get_web_shader_compile_status();\n\tRID version_create();')
replace(C, '#include "drivers/gles3/storage/config.h"', '#include "drivers/gles3/storage/config.h"\n#ifdef WEB_ENABLED\n#include <emscripten/html5_webgl.h>\n#endif')
replace(C, '\tname = p_name;', '\tname = p_name;\n#ifdef WEB_ENABLED\n\tweb_scene_shader = name == "SceneShaderGLES3";\n#endif')
replace(C, '''void ShaderGLES3::_compile_specialization(Version::Specialization &spec, uint32_t p_variant, Version *p_version, uint64_t p_specialization) {
	spec.id = glCreateProgram();''', '''void ShaderGLES3::_compile_specialization(Version::Specialization &spec, uint32_t p_variant, Version *p_version, uint64_t p_specialization) {
#ifdef WEB_ENABLED
	if (web_scene_shader && web_parallel_supported) {
		_submit_web_specialization(spec, p_variant, p_version, p_specialization);
		return;
	}
#endif
	spec.id = glCreateProgram();''')
replace(C, '''void ShaderGLES3::_clear_version(Version *p_version) {
''', '''void ShaderGLES3::_clear_version(Version *p_version) {
#ifdef WEB_ENABLED
	for (uint32_t i = 0; i < web_pending.size();) {
		if (web_pending[i].version == p_version && web_pending[i].shader == this) {
			web_pending.remove_at(i);
			web_cancelled++;
		} else {
			i++;
		}
	}
#endif
''')
replace(C, '''		Version::Specialization spec;
		_compile_specialization(spec, i, p_version, specialization_default_mask);
		p_version->variants[i].insert(specialization_default_mask, spec);''', '''#ifdef WEB_ENABLED
		if (web_scene_shader) {
			// Compile only variants that the actual scene requests.
			continue;
		}
#endif
		Version::Specialization spec;
		_compile_specialization(spec, i, p_version, specialization_default_mask);
		p_version->variants[i].insert(specialization_default_mask, spec);''')
replace(C, '''void ShaderGLES3::initialize(const String &p_general_defines, int p_base_texture_index) {
	general_defines''', '''void ShaderGLES3::initialize(const String &p_general_defines, int p_base_texture_index) {
#ifdef WEB_ENABLED
	if (!web_extension_checked) {
		web_parallel_supported = emscripten_webgl_enable_extension(emscripten_webgl_get_current_context(), "KHR_parallel_shader_compile");
		web_extension_checked = true;
	}
#endif
	general_defines''')
async_code=r'''
#ifdef WEB_ENABLED
LocalVector<ShaderGLES3::WebPending> ShaderGLES3::web_pending;
bool ShaderGLES3::web_extension_checked = false;
bool ShaderGLES3::web_parallel_supported = false;
uint64_t ShaderGLES3::web_submitted = 0;
uint64_t ShaderGLES3::web_completed = 0;
uint64_t ShaderGLES3::web_failed = 0;
uint64_t ShaderGLES3::web_cancelled = 0;
uint64_t ShaderGLES3::web_skipped_binds = 0;
Vector<String> ShaderGLES3::web_errors;

void ShaderGLES3::_submit_web_specialization(Version::Specialization &spec, uint32_t p_variant, Version *p_version, uint64_t p_specialization) {
	spec.id = glCreateProgram();
	spec.ok = false;
	spec.build_queued = true;
	for (int stage = 0; stage < STAGE_TYPE_MAX; stage++) {
		StringBuilder builder;
		_build_variant_code(builder, p_variant, p_version, StageType(stage), p_specialization);
		CharString code = builder.as_string().utf8();
		const char *source = code.ptr();
		GLint length = code.length();
		GLuint shader = glCreateShader(stage == STAGE_TYPE_VERTEX ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER);
		if (stage == STAGE_TYPE_VERTEX) {
			spec.vert_id = shader;
		} else {
			spec.frag_id = shader;
		}
		glShaderSource(shader, 1, &source, &length);
		glCompileShader(shader);
		glAttachShader(spec.id, shader);
	}
	if (feedback_count) {
		Vector<const char *> feedback;
		for (int i = 0; i < feedback_count; i++) {
			if (feedbacks[i].specialization == 0 || (feedbacks[i].specialization & p_specialization)) {
				feedback.push_back(feedbacks[i].name);
			}
		}
		if (feedback.size()) {
			glTransformFeedbackVaryings(spec.id, feedback.size(), feedback.ptr(), GL_INTERLEAVED_ATTRIBS);
		}
	}
	glLinkProgram(spec.id);
	WebPending pending;
	pending.shader = this;
	pending.version = p_version;
	pending.variant = p_variant;
	pending.specialization = p_specialization;
	web_pending.push_back(pending);
	web_submitted++;
}

void ShaderGLES3::_finish_web_specialization(Version::Specialization &spec, Version *p_version) {
	GLint vertex_ok = GL_FALSE;
	GLint fragment_ok = GL_FALSE;
	GLint link_ok = GL_FALSE;
	// Only query the blocking statuses after KHR completion has signalled.
	glGetShaderiv(spec.vert_id, GL_COMPILE_STATUS, &vertex_ok);
	glGetShaderiv(spec.frag_id, GL_COMPILE_STATUS, &fragment_ok);
	glGetProgramiv(spec.id, GL_LINK_STATUS, &link_ok);
	spec.build_queued = false;
	if (!vertex_ok || !fragment_ok || !link_ok) {
		String error = name + ": asynchronous Web shader compilation/link failed.";
		for (int i = 0; i < 3; i++) {
			GLint length = 0;
			if (i == 2) {
				glGetProgramiv(spec.id, GL_INFO_LOG_LENGTH, &length);
			} else {
				glGetShaderiv(i == 0 ? spec.vert_id : spec.frag_id, GL_INFO_LOG_LENGTH, &length);
			}
			if (length > 1) {
				Vector<char> log;
				log.resize(length + 1);
				GLsizei written = 0;
				if (i == 2) {
					glGetProgramInfoLog(spec.id, length, &written, log.ptrw());
				} else {
					glGetShaderInfoLog(i == 0 ? spec.vert_id : spec.frag_id, length, &written, log.ptrw());
				}
				log.ptrw()[written] = '\0';
				error += "\n" + String::utf8(log.ptr(), written);
			}
		}
		web_failed++;
		if (web_errors.size() < 32) {
			web_errors.push_back(error);
		}
		ERR_PRINT(error);
		glDeleteShader(spec.vert_id);
		glDeleteShader(spec.frag_id);
		glDeleteProgram(spec.id);
		spec.id = spec.vert_id = spec.frag_id = 0;
		return;
	}
	GLint previous_program = 0;
	glGetIntegerv(GL_CURRENT_PROGRAM, &previous_program);
	_get_uniform_locations(spec, p_version);
	glUseProgram(previous_program);
	spec.ok = true;
	web_completed++;
}

void ShaderGLES3::_poll_web_specializations() {
	for (uint32_t i = 0; i < web_pending.size();) {
		const WebPending &pending = web_pending[i];
		Version::Specialization *spec = pending.version->variants[pending.variant].getptr(pending.specialization);
		if (!spec) {
			// Submission is inserted into its map immediately after returning.
			i++;
			continue;
		}
		GLint complete = GL_FALSE;
		glGetProgramiv(spec->id, 0x91B1 /* GL_COMPLETION_STATUS_KHR */, &complete);
		if (!complete) {
			i++;
			continue;
		}
		pending.shader->_finish_web_specialization(*spec, pending.version);
		web_pending.remove_at(i);
	}
}
#endif

Dictionary ShaderGLES3::get_web_shader_compile_status() {
	Dictionary result;
#ifdef WEB_ENABLED
	_poll_web_specializations();
	result["extension_checked"] = web_extension_checked;
	result["extension"] = web_parallel_supported;
	result["async_enabled"] = web_parallel_supported;
	result["pending"] = int64_t(web_pending.size());
	result["submitted"] = int64_t(web_submitted);
	result["completed"] = int64_t(web_completed);
	result["failed"] = int64_t(web_failed);
	result["cancelled"] = int64_t(web_cancelled);
	result["skipped_binds"] = int64_t(web_skipped_binds);
	result["errors"] = web_errors;
	result["scope"] = "Web scene shaders; other shader classes remain synchronous";
#else
	result["async_enabled"] = false;
	result["pending"] = 0;
	result["scope"] = "Not a Web build";
#endif
	return result;
}
'''
replace(C,'RenderingServerTypes::ShaderNativeSourceCode ShaderGLES3::version_get_native_source_code',async_code+'\nRenderingServerTypes::ShaderNativeSourceCode ShaderGLES3::version_get_native_source_code')
replace(RH,'\tvirtual String shader_get_code(RID p_shader) const = 0;', '\tvirtual String shader_get_code(RID p_shader) const = 0;\n\tDictionary get_web_shader_compile_status();')
replace(RC,'#include "servers/rendering/shader_warnings.h"', '#include "servers/rendering/shader_warnings.h"\n#if defined(WEB_ENABLED) && defined(GLES3_ENABLED)\n#include "drivers/gles3/shader_gles3.h"\n#endif')
replace(RC, 'RenderingServer *RenderingServer::singleton = nullptr;', '''Dictionary RenderingServer::get_web_shader_compile_status() {
#if defined(WEB_ENABLED) && defined(GLES3_ENABLED)
	return ShaderGLES3::get_web_shader_compile_status();
#else
	Dictionary result;
	result["async_enabled"] = false;
	result["pending"] = 0;
	return result;
#endif
}

RenderingServer *RenderingServer::singleton = nullptr;''')
replace(RC, '\tClassDB::bind_method(D_METHOD("shader_get_code", "shader"), &RenderingServer::shader_get_code);', '\tClassDB::bind_method(D_METHOD("shader_get_code", "shader"), &RenderingServer::shader_get_code);\n\tClassDB::bind_method(D_METHOD("get_web_shader_compile_status"), &RenderingServer::get_web_shader_compile_status);')
replace('platform/web/detect.py', '    env["ARCOM"] = "${TEMPFILE(\'$ARCOM_POSIX\',\'$ARCOMSTR\')}"', '''    env["ARCOM"] = "${TEMPFILE('$ARCOM_POSIX','$ARCOMSTR')}"
    if sys.platform == "win32":
        import shlex

        # Windows em++.bat cannot accept the full final-link command line.
        # Use the same official SCons response-file facility as AR above.
        # emcc parses response files using POSIX shlex; quote backslashes too.
        env["TEMPFILEARGESCFUNC"] = lambda arg: shlex.quote(str(arg))
        env["LINKCOM_POSIX"] = env["LINKCOM"].replace("$TARGET", "$TARGET.posix").replace("$SOURCES", "$SOURCES.posix")
        env["LINKCOM"] = "${TEMPFILE('$LINKCOM_POSIX','$LINKCOMSTR')}"''')
patch=[]; manifest={}
for p in FILES:
    before=original[p]; after=(SRC/p).read_text(encoding='utf-8')
    baseline=ROOT/'baseline'/p
    baseline.parent.mkdir(parents=True,exist_ok=True)
    baseline.write_text(before,encoding='utf-8',newline='\n')
    patch.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+p,tofile='b/'+p))
    manifest[p]={'baseline_sha256':hashlib.sha256(before.encode()).hexdigest(),'patched_sha256':hashlib.sha256(after.encode()).hexdigest()}
(ROOT/'web-parallel-scene-shaders.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
(ROOT/'patch-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Patched exactly',len(FILES),'official-source files.')
