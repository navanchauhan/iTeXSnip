import hashlib
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pathlib import Path
from PIL import Image
import io

app = FastAPI()

images_dir = Path("images")
images_dir.mkdir(exist_ok=True)

MAX_FILE_SIZE = 25 * 1024 * 1024


@app.post("/rate_snippet")
async def rate_snippet(good: bool = False, image: UploadFile = File(...)):
    image_content = await image.read()
    image_size = len(image_content)

    if image_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400, detail="File too large. Maximum file size is 25MB."
        )

    img = Image.open(io.BytesIO(image_content))
    sha256_hash = hashlib.sha256(image_content).hexdigest()

    if good:
        fname = f"{sha256_hash}_good.png"
    else:
        fname = f"{sha256_hash}_bad.png"

    img.save(f"{images_dir}/{fname}", format="PNG")
    return {"message": "Thank you for rating the snippet!", "image_size": image_size}
