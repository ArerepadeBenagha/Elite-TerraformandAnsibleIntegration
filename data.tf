# data "cloudinit_config" "hostip" {
#   gzip          = false
#   base64_encode = false

#   part {
#     content_type = "text/x-shellscript"
#     filename     = "scripts"
#     content = templatefile("./scripts/script.sh",
#       {
#         hostip   = var.host
#         key_path = var.key_path
#     })
#   }
# }