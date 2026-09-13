def fill($v; $t): gsub("\\{version\\}"; $v) | gsub("\\{tag\\}"; $t);
.apps[]
| .version as $v
| ((.tag // "v{version}") | gsub("\\{version\\}"; $v)) as $t
| (if has("repo") then .tag = $t else . end)
| with_entries(if (.key | IN("asset", "url", "extract_dir")) then .value |= fill($v; $t) else . end)
| .path //= ["."]
| .bin //= []
