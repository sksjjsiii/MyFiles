import os
import json
import time
import secrets
import warnings
from typing import List, Optional, Dict, Any

import g4f
from fastapi import FastAPI, Depends, HTTPException, Header
from pydantic import BaseModel, Field
import uvicorn

g4f.debug.logging = False
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=RuntimeWarning)

app = FastAPI(
    title="AI Chat API with Tool Calling",
    description="API for chat with AI using g4f and DeepInfra, with support for function calling.",
    version="1.0.0"
)

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_NAME = "zai-org/GLM-5.2"
PROVIDER = g4f.Provider.DeepInfra

API_KEY = os.getenv("RDP_PASSWORD")
if not API_KEY:
    raise RuntimeError(
        "Environment variable RDP_PASSWORD is not set. "
        "Please set it before running the server."
    )

def verify_api_key(api_key: str) -> bool:
    return secrets.compare_digest(api_key, API_KEY)

class Message(BaseModel):
    role: str
    content: Optional[str] = None
    tool_calls: Optional[List[Dict[str, Any]]] = None
    tool_call_id: Optional[str] = None

class ToolFunction(BaseModel):
    name: str
    description: str
    parameters: Dict[str, Any]

class Tool(BaseModel):
    type: str = "function"
    function: ToolFunction

class ChatCompletionRequest(BaseModel):
    messages: List[Message]
    tools: Optional[List[Tool]] = None
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None
    top_p: Optional[float] = None

class ChatCompletionResponse(BaseModel):
    id: str
    object: str
    created: int
    model: str
    choices: List[Dict[str, Any]]
    usage: Optional[Dict[str, int]] = None

async def get_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    if not verify_api_key(x_api_key):
        raise HTTPException(status_code=401, detail="Invalid API key")
    return x_api_key

def convert_g4f_response(g4f_response, model_name: str) -> Dict[str, Any]:
    message = g4f_response.choices[0].message
    content = getattr(message, 'content', None)
    tool_calls_raw = getattr(message, 'tool_calls', None)

    tool_calls = None
    if tool_calls_raw:
        tool_calls = []
        for tc in tool_calls_raw:
            tool_calls.append({
                "id": tc.id,
                "type": "function",
                "function": {
                    "name": tc.function.name,
                    "arguments": tc.function.arguments
                }
            })

    finish_reason = "tool_calls" if tool_calls else "stop"

    return {
        "id": getattr(g4f_response, 'id', f"chatcmpl-{int(time.time())}"),
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model_name,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": content,
                    "tool_calls": tool_calls
                },
                "finish_reason": finish_reason
            }
        ],
        "usage": getattr(g4f_response, 'usage', None)
    }

@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def chat_completions(
    request: ChatCompletionRequest,
    api_key: str = Depends(get_api_key)
):
    messages = []
    for msg in request.messages:
        msg_dict = {"role": msg.role, "content": msg.content}
        if msg.tool_calls is not None:
            msg_dict["tool_calls"] = msg.tool_calls
        if msg.tool_call_id is not None:
            msg_dict["tool_call_id"] = msg.tool_call_id
        messages.append(msg_dict)

    tools = None
    if request.tools:
        tools = [tool.dict() for tool in request.tools]

    params = {
        "model": MODEL_NAME,
        "messages": messages,
        "provider": PROVIDER,
        "stream": False,
    }
    if tools:
        params["tools"] = tools
        params["tool_choice"] = "auto"
    if request.temperature is not None:
        params["temperature"] = request.temperature
    if request.max_tokens is not None:
        params["max_tokens"] = request.max_tokens
    if request.top_p is not None:
        params["top_p"] = request.top_p

    try:
        client = g4f.Client()
        response = client.chat.completions.create(**params)
        return convert_g4f_response(response, MODEL_NAME)
    except Exception as e:
        print(f"Error during completion: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/api/status")
async def api_status(api_key: str = Depends(get_api_key)):
    return {"status": "ok", "model": MODEL_NAME}

@app.get("/v1/models")
async def list_models(api_key: str = Depends(get_api_key)):
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "created": int(time.time()),
                "owned_by": "DeepInfra"
            }
        ]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
