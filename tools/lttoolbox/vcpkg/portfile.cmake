include(vcpkg_common_functions)

vcpkg_from_github(
	OUT_SOURCE_PATH SOURCE_PATH
	REPO apertium/lttoolbox
	REF 841a0e9a032438d78f5b3ee6aa298daf9f9d0838
	SHA512 fdc94bad9e42427c26ecfa055df9a19135716be09716214394530e626273d2221ee14c4eb4f8d7cce6aeb01222e6e0e34531e19f0954c8f0faa5f5f85547996c
	HEAD_REF cmake
)

vcpkg_find_acquire_program(PYTHON3)
set(VCPKG_PYTHON_EXECUTABLE "${PYTHON3}")

vcpkg_configure_cmake(
	SOURCE_PATH ${SOURCE_PATH}
	PREFER_NINJA
)

vcpkg_install_cmake()
file(INSTALL ${SOURCE_PATH}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/lttoolbox RENAME copyright)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools/lttoolbox)
file(GLOB exes RELATIVE ${CURRENT_PACKAGES_DIR}/bin/ ${CURRENT_PACKAGES_DIR}/bin/*.exe)
foreach(exe ${exes})
	file(REMOVE ${CURRENT_PACKAGES_DIR}/debug/bin/${exe})
	file(RENAME ${CURRENT_PACKAGES_DIR}/bin/${exe} ${CURRENT_PACKAGES_DIR}/tools/lttoolbox/${exe})
endforeach()
