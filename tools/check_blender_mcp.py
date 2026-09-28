"""Actual MCP stdio handshake -> official Blender Lab -> dedicated local Blender."""
import asyncio
import json
import os
import base64
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'evidence/visual-upgrade-20260923/blender-mcp-repair'

async def main():
    env = dict(os.environ, BLENDER_MCP_HOST='127.0.0.1', BLENDER_MCP_PORT='9876')
    params = StdioServerParameters(command='C:/Users/tsang/Tools/blender-mcp/mcp/.venv/Scripts/blender-mcp.exe',args=['--transport','stdio'],env=env)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            initialized = await session.initialize()
            listed = await session.list_tools()
            (OUT/'tools.json').write_text(listed.model_dump_json(indent=2),encoding='utf-8')
            scene = await session.call_tool('execute_blender_code', {'code': "import bpy\nresult={'version':bpy.app.version_string,'file':bpy.data.filepath,'objects':len(bpy.data.objects),'windows':len(bpy.context.window_manager.windows),'bridge':'official Blender Lab'}"})
            # A disposable empty verifies the mutation/readback path; no source file is saved.
            edit = await session.call_tool('execute_blender_code', {'code': "import bpy\nname='Codex_MCP_Connection_Probe'\nassert bpy.data.objects.get(name) is None\no=bpy.data.objects.new(name,None)\nbpy.context.scene.collection.objects.link(o)\no.location=(1.25,2.5,3.75)\nresult={'created':o.name,'position':list(o.location)}\nbpy.data.objects.remove(o,do_unlink=True)\nresult['removed_after_test']=bpy.data.objects.get(name) is None"})
            report={'kind':'actual_MCP_stdio_end_to_end','server':initialized.serverInfo.model_dump(),'toolCount':len(listed.tools),'tools':[t.name for t in listed.tools],'scene':scene.model_dump(mode='json'),'editReadback':edit.model_dump(mode='json'),'sourceSaved':False}
            (OUT/'connection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
            print(json.dumps(report,ensure_ascii=False))
            assert not scene.isError and not edit.isError

asyncio.run(main())
