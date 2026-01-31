# Manually fix patches

To fix patches manually, either get the .rej and .orig files out of the Docker container or find the original file online.

After that, copy the original file and apply the patch manually.

Then, use the diff command to create a new patch file.

For example:

```sh
diff -u original-file.c patched-file.c > new-patch-file.patch
```

After that modify the header to include the Git commit info and set proper directory of the file, then copy it to the patches/ directory and use it during the build.
