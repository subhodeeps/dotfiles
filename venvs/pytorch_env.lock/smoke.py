import torch, torchvision, torchmetrics
print(torch.__version__, "CUDA:", torch.cuda.is_available())
assert torch.cuda.is_available(), "CUDA not available"
