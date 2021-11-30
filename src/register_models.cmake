
#function(switch_expr INPUT OUTPUT)
#    list(LENGTH ARGN N)
#    math(EXPR EVEN "${N} % 2")
#    if (NOT EVEN EQUAL 0)
#        message(FATAL_ERROR "Expr must be a list of string pairs, ${EVEN}")
#    endif ()
#    math(EXPR N_ "${N}-1")
#    foreach (idx RANGE 0 ${N_} 2)
#        math(EXPR KEY_IDX "${idx} + 0")
#        math(EXPR VALUE_IDX "${idx} + 1")
#        list(GET ARGN ${KEY_IDX} KEY)
#        list(GET ARGN ${VALUE_IDX} VALUE)
#        if (${KEY} STREQUAL ${INPUT})
#            set(${OUTPUT} ${VALUE} PARENT_SCOPE)
#            break()
#        endif ()
#    endforeach ()
#endfunction()
#

macro(wipe_gcc_style_optimisation_flags VAR)
    if(${VAR})
        string(REGEX REPLACE "([\\/\\-]O.)" "" ${VAR} ${${VAR}})
    endif()
endmacro()

macro(register_link_library)
    list(APPEND LINK_LIBRARIES ${ARGN})
endmacro()

macro(register_append_cxx_flags CONFIG)
    if ("${CONFIG}" STREQUAL "RELEASE" OR "${CONFIG}" STREQUAL "ANY")
        list(APPEND DEFAULT_RELEASE_FLAGS ${ARGN})
    elseif ("${CONFIG}" STREQUAL "DEBUG" OR "${CONFIG}" STREQUAL "ANY")
        list(APPEND DEFAULT_DEBUG_FLAGS ${ARGN})
    else ()
        message(FATAL_ERROR "register_flags supports only RELEASE, DEBUG, or ANY for all configs, got `${CONFIG}`")
    endif ()
endmacro()

macro(register_append_link_flags)
    list(APPEND LINK_FLAGS ${ARGN})
endmacro()

function(bind_cxx_and_arch OUT PREFIX CXX ARCH)
    string(TOUPPER ${CXX} _CXX)
    string(TOUPPER ${ARCH} _ARCH)
    set(_CXX_ARCH_SPECIFIC_FLAGS "${${PREFIX}_${_CXX}_${_ARCH}}")
    if (_CXX_ARCH_SPECIFIC_FLAGS)
        register_append_cxx_flags(ANY ${_CXX_ARCH_SPECIFIC_FLAGS})
    endif ()
    set(_CXX_ARCH_SPECIFIC_FLAGS "${${PREFIX}_${_CXX}}")
    if (_CXX_ARCH_SPECIFIC_FLAGS)
        register_append_cxx_flags(ANY ${_CXX_ARCH_SPECIFIC_FLAGS})
    endif ()
    set(${OUT} "${_CXX_ARCH_SPECIFIC_FLAGS}" PARENT_SCOPE)
endfunction()

macro(register_append_compiler_and_arch_specific_cxx_flags PREFIX CXX ARCH)
    bind_cxx_and_arch(OUT ${PREFIX} ${CXX} ${ARCH})
    register_append_cxx_flags(ANY ${OUT})
endmacro()

macro(register_append_compiler_and_arch_specific_link_flags PREFIX CXX ARCH)
    bind_cxx_and_arch(OUT ${PREFIX} ${CXX} ${ARCH})
    register_append_link_flags(${OUT})
endmacro()

macro(register_definitions)
    list(APPEND IMPL_DEFINITIONS ${ARGN})
endmacro()

macro(register_flag_required NAME DESCRIPTION)
    list(APPEND CUSTOM_FLAGS_TRIPLE "${NAME}" "${DESCRIPTION}" ON "")
endmacro()

macro(register_flag_optional NAME DESCRIPTION DEFAULT)
    list(APPEND CUSTOM_FLAGS_TRIPLE "${NAME}" "${DESCRIPTION}" OFF "${DEFAULT}")
endmacro()

function(registered_flags_action ACTION OUT)
    list(LENGTH CUSTOM_FLAGS_TRIPLE NFLAGS)
    if (NOT NFLAGS EQUAL "0")

        if (${ACTION} STREQUAL "print")
            set(LINE "Supported flags:\n\n")
        elseif (${ACTION} STREQUAL "check")
            set(LINE "Model-specific flags for this build:\n\n")
        endif ()


        math(EXPR NFLAGS "${NFLAGS}-1")
        foreach (idx RANGE 0 ${NFLAGS} 4)
            math(EXPR NAME_IDX "${idx} + 0")
            math(EXPR DESCRIPTION_IDX "${idx} + 1")
            math(EXPR REQUIRED_IDX "${idx} + 2")
            math(EXPR DEFAULT_VALUE_IDX "${idx} + 3")
            list(GET CUSTOM_FLAGS_TRIPLE ${NAME_IDX} NAME)
            list(GET CUSTOM_FLAGS_TRIPLE ${DESCRIPTION_IDX} DESCRIPTION)
            list(GET CUSTOM_FLAGS_TRIPLE ${REQUIRED_IDX} REQUIRED)
            list(GET CUSTOM_FLAGS_TRIPLE ${DEFAULT_VALUE_IDX} DEFAULT_VALUE)
            if (${ACTION} STREQUAL "print")
                if (${REQUIRED})
                    set(DEFAULT_VALUE "(required)")
                else ()
                    set(DEFAULT_VALUE "(optional, default=${DEFAULT_VALUE})")
                endif ()
                set(LINE "${LINE}   ${NAME} ${DEFAULT_VALUE}: ${DESCRIPTION}\n")
            elseif (${ACTION} STREQUAL "check")
                if (${REQUIRED})
                    # required flag
                    if (NOT DEFINED ${NAME})
                        message(FATAL_ERROR "`${NAME}` is not set! (${DESCRIPTION})")
                    endif ()
                else ()
                    # optional flag with default
                    if (NOT DEFINED ${NAME})
                        set(${NAME} "${DEFAULT_VALUE}" PARENT_SCOPE) # setting PARENT_SCOPE does not affect local scope
                        set(${NAME} "${DEFAULT_VALUE}")
                    endif ()
                endif ()
                set(LINE "${LINE}   ${NAME} = `${${NAME}}`\n")
            else ()
                message(FATAL_ERROR "action `${ACTION}` not supported")
            endif ()
        endforeach ()
    endif ()
    set(${OUT} "${LINE}" PARENT_SCOPE)
endfunction()


macro(register_model NAME PREPROCESSOR_NAME)
    list(APPEND REGISTERED_MODELS "${NAME}")

    string(TOUPPER ${NAME} MODEL_UPPER)
    list(APPEND IMPL_${MODEL_UPPER}_SOURCES "${NAME}/${ARGN}")
    list(APPEND IMPL_${MODEL_UPPER}_DEFINITIONS "${PREPROCESSOR_NAME}")
endmacro()


macro(load_model MODEL)
    if ("${MODEL}" IN_LIST REGISTERED_MODELS)
        string(TOLOWER "${MODEL}" MODEL_LOWER)
        set(MODEL_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${MODEL_LOWER}/model.cmake)
        include_directories(${CMAKE_CURRENT_SOURCE_DIR}/${MODEL_LOWER})
        if (NOT EXISTS ${MODEL_FILE})
            message(FATAL_ERROR "${MODEL_FILE} not found, perhaps it needs to be implemented?")
        endif ()
        include(${MODEL_FILE})
        string(TOUPPER "${MODEL}" MODEL_UPPER)
        list(APPEND IMPL_SOURCES ${IMPL_${MODEL_UPPER}_SOURCES})
        list(APPEND IMPL_DEFINITIONS ${IMPL_${MODEL_UPPER}_DEFINITIONS})

        string(TOLOWER ${MODEL} MODEL_LOWER)
        set(EXE_NAME ${MODEL_LOWER}-stream)

    else ()
        message(FATAL_ERROR "Unsupported model: ${MODEL}")
    endif ()
endmacro()