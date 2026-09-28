"""Start the already-installed official Blender Lab bridge in this dedicated session."""
import bpy
import addon_utils

addon_utils.enable('mcp', default_set=False, persistent=False)
from mcp import mcp_to_blender_server

preferences = bpy.context.preferences.addons['mcp'].preferences
preferences.host = '127.0.0.1'
preferences.port = 9876
if not mcp_to_blender_server.is_running():
    result = bpy.ops.blmcp.server_start()
    assert result == {'FINISHED'}, result
print('OFFICIAL_BLENDER_LAB_BRIDGE_READY 127.0.0.1:9876', flush=True)
