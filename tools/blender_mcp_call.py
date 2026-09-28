"""Thin SDK client for this turn's official configured MCP; no alternate bridge server."""
import argparse
import asyncio
import base64
import json
import os
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def run(args):
    params=StdioServerParameters(command='C:/Users/tsang/Tools/blender-mcp/mcp/.venv/Scripts/blender-mcp.exe',args=['--transport','stdio'],env=dict(os.environ,BLENDER_MCP_HOST='127.0.0.1',BLENDER_MCP_PORT='9876'))
    arguments=json.loads(args.arguments)
    if args.code_file:
        arguments={'code':Path(args.code_file).read_text(encoding='utf-8-sig')}
    async with stdio_client(params) as (read,write):
        async with ClientSession(read,write) as session:
            await session.initialize()
            result=await session.call_tool(args.tool,arguments)
            output=Path(args.output)
            output.parent.mkdir(parents=True,exist_ok=True)
            output.write_text(result.model_dump_json(indent=2),encoding='utf-8')
            for i,block in enumerate(result.content):
                if block.type=='image':
                    path=output.with_name(output.stem+f'-{i}.png')
                    path.write_bytes(base64.b64decode(block.data));print(str(path))
                elif block.type=='text': print(block.text)
            if result.isError: raise SystemExit(1)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--tool',default='execute_blender_code')
    parser.add_argument('--arguments',default='{}')
    parser.add_argument('--code-file')
    parser.add_argument('--output',required=True)
    asyncio.run(run(parser.parse_args()))
