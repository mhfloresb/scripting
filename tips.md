# Eliminar malware.
find . -type f -name "*" -print | xargs sed -i "s|var\ _0xc790=.*(\_0xc790\[0\]))||"
