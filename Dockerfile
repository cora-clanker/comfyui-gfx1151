FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.12_pytorch_release_2.9.1

SHELL ["/bin/bash", "-c"]

# flash-attention via Triton backend (already in rocm/pytorch image).
# The env var tells ComfyUI/torch that flash-attention is available; the
# python setup.py install just wires up the frontend.
ENV FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE

RUN cd /opt && \
    git clone https://github.com/ROCm/flash-attention.git && \
    cd flash-attention && \
    git checkout main_perf && \
    python setup.py install

# ── Custom ComfyUI frontend ───────────────────────────────────────────────────
# Build cora-clanker/ComfyUI_frontend into a comfyui-frontend-package wheel.
# Installed after ComfyUI requirements so it overrides the pinned upstream one.
ARG COMFYUI_FRONTEND_REF=main
ARG NODE_MAJOR=24
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@10 && \
    pip install build

RUN git clone https://github.com/cora-clanker/ComfyUI_frontend /opt/ComfyUI_frontend && \
    cd /opt/ComfyUI_frontend && \
    git checkout ${COMFYUI_FRONTEND_REF} && \
    pnpm install --frozen-lockfile && \
    NODE_OPTIONS='--max-old-space-size=8192' pnpm build && \
    mkdir -p comfyui_frontend_package/comfyui_frontend_package/static && \
    cp -r dist/* comfyui_frontend_package/comfyui_frontend_package/static/ && \
    cd comfyui_frontend_package && \
    COMFYUI_FRONTEND_VERSION="$(node -p "require('/opt/ComfyUI_frontend/package.json').version")" \
        python -m build --wheel

# ── ComfyUI ───────────────────────────────────────────────────────────────────
# Pin to a specific ref. Pass --build-arg COMFYUI_REF=<tag-or-sha> to override.
ARG COMFYUI_REF=v0.15.0
RUN git clone https://github.com/comfyanonymous/ComfyUI /opt/ComfyUI && \
    cd /opt/ComfyUI && \
    git checkout ${COMFYUI_REF} && \
    pip install -r requirements.txt && \
    pip install --no-deps --force-reinstall /opt/ComfyUI_frontend/comfyui_frontend_package/dist/*.whl

WORKDIR /opt/ComfyUI/custom_nodes

# ── rgthree-comfy ─────────────────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    if [ -f rgthree-comfy/requirements.txt ]; then pip install -r rgthree-comfy/requirements.txt; fi

# ── ComfyUI-Inpaint-CropAndStitch ─────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    if [ -f ComfyUI-Inpaint-CropAndStitch/requirements.txt ]; then pip install -r ComfyUI-Inpaint-CropAndStitch/requirements.txt; fi

# ── comfyui_controlnet_aux ────────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    pip install -r comfyui_controlnet_aux/requirements.txt

# ── ComfyUI-RMBG ──────────────────────────────────────────────────────────────
# GroundingDINO in requirements.txt builds from source and needs gcc/g++.
# Skip it; the rest (RMBG, BiRefNet, SAM, etc.) works without it.
RUN git clone --depth 1 https://github.com/1038lab/ComfyUI-RMBG.git && \
    grep -v 'groundingdino' ComfyUI-RMBG/requirements.txt | pip install -r /dev/stdin

# ── ComfyUI-Easy-Sam3 ─────────────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Sam3.git && \
    if [ -f ComfyUI-Easy-Sam3/requirements.txt ]; then pip install -r ComfyUI-Easy-Sam3/requirements.txt; fi

# ── ComfyUI-SCAIL-Pose ────────────────────────────────────────────────────────
# Dependencies from pyproject.toml: taichi >= 1.7.4, opencv-python, pillow.
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-SCAIL-Pose.git && \
    pip install "taichi>=1.7.4" opencv-python pillow

# ── ComfyUI-iTools ────────────────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/MohammadAboulEla/ComfyUI-iTools.git && \
    if [ -f ComfyUI-iTools/requirements.txt ]; then pip install -r ComfyUI-iTools/requirements.txt; fi

# ── ComfyUI-Manager ───────────────────────────────────────────────────────────
# Directory name must be exactly 'comfyui-manager' (lowercase) per project docs;
# otherwise Manager cannot identify itself for self-updates.
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git comfyui-manager && \
    pip install -r comfyui-manager/requirements.txt

# ── debugging utilities ───────────────────────────────────────────────────────
RUN mkdir -p /opt/comfyui-gfx1151-utils
WORKDIR /opt/comfyui-gfx1151-utils
ADD scripts/test-pytorch.sh test-pytorch.sh
ADD scripts/test-pytorch-flashattention.py test-pytorch-flashattention.py
RUN chmod +x test-pytorch.sh test-pytorch-flashattention.py

WORKDIR /opt/ComfyUI

EXPOSE 8188

CMD ["python3", "/opt/ComfyUI/main.py", "--listen", "0.0.0.0", "--use-flash-attention", "--normalvram", "--disable-api-nodes"]
