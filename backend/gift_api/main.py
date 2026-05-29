from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
import os
import json
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

GROQ_KEY = os.getenv("GROQ_API_KEY")
SERP_KEY = os.getenv("SERP_API_KEY")

class GiftRequest(BaseModel):
    query: str
    budget: int = 1000
    currency: str = "INR"
    partner_context: str = ""

@app.post("/search-gifts")
async def search_gifts(req: GiftRequest):
    if not GROQ_KEY or not SERP_KEY:
        raise HTTPException(status_code=500, detail="Missing API keys in environment.")

    groq_prompt = f"""
    User wants a gift: "{req.query}"
    Budget: ₹{req.budget}
    Partner preferences: {req.partner_context}
    
    Extract a clean search query for finding this product online in India.
    Return JSON only: {{"search_query": "...", "category": "...", "emotional_note": "why this matches her"}}
    """
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        # Step 1: Groq processing
        try:
            groq_resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {GROQ_KEY}"},
                json={
                    "model": "llama3-8b-8192",
                    "messages": [{"role": "user", "content": groq_prompt}],
                    "max_tokens": 300,
                    "temperature": 0.5
                }
            )
            groq_resp.raise_for_status()
            groq_data = groq_resp.json()
            
            raw_content = groq_data["choices"][0]["message"]["content"]
            clean_json_str = raw_content.replace('```json', '').replace('```', '').strip()
            intent = json.loads(clean_json_str)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to process intent with Groq: {str(e)}")

        # Step 2: SerpAPI Shopping Search
        try:
            search_query = f"{intent.get('search_query', req.query)} site:flipkart.com OR site:amazon.in OR site:myntra.com"
            serp_resp = await client.get(
                "https://serpapi.com/search",
                params={
                    "q": search_query,
                    "tbm": "shop",
                    "api_key": SERP_KEY,
                    "gl": "in",
                    "hl": "en",
                    "num": 5,
                    "tbs": f"mr:1,price:1,ppr_max:{req.budget}"
                }
            )
            serp_resp.raise_for_status()
            serp_data = serp_resp.json()
            
            products = []
            for item in serp_data.get("shopping_results", [])[:5]:
                products.append({
                    "title": item.get("title", ""),
                    "price": item.get("price", ""),
                    "link": item.get("link", ""),
                    "thumbnail": item.get("thumbnail", ""),
                    "source": item.get("source", ""),
                    "emotional_note": intent.get("emotional_note", "")
                })
            
            return {"products": products, "search_query": intent.get("search_query", req.query)}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to search products with SerpAPI: {str(e)}")

@app.get("/health")
async def health():
    return {"status": "ok"}
