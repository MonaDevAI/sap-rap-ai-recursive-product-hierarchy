CLASS zcl_product_hierarchy_ai_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.
    CONSTANTS gc_destination TYPE rfcdest VALUE 'ZPRODUCT_HIER_AI'.
    CONSTANTS gc_resource TYPE string VALUE '/chat/completions'.
    CONSTANTS gc_max_request_length TYPE i VALUE 32768.

    TYPES:
      BEGIN OF ty_http_request,
        operation     TYPE string,
        hierarchy     TYPE zcl_product_hierarchy_ai=>ty_hierarchy,
        product_id    TYPE string,
        product_name  TYPE string,
        product_type  TYPE string,
        max_depth     TYPE i,
      END OF ty_http_request,
      BEGIN OF ty_http_response,
        success       TYPE abap_bool,
        content       TYPE string,
        error_message TYPE string,
      END OF ty_http_response.

    METHODS send_response
      IMPORTING
        io_server   TYPE REF TO if_http_server
        iv_status   TYPE i
        is_response TYPE ty_http_response.
ENDCLASS.


CLASS zcl_product_hierarchy_ai_http IMPLEMENTATION.
  METHOD if_http_extension~handle_request.
    DATA(lv_method) = server->request->get_header_field( '~request_method' ).

    IF lv_method <> 'POST'.
      server->response->set_header_field( name = 'Allow' value = 'POST' ).
      send_response(
        io_server = server
        iv_status = 405
        is_response = VALUE #(
          error_message = 'Only POST requests are supported.' ) ).
      RETURN.
    ENDIF.

    DATA(lv_request_body) = server->request->get_cdata( ).
    IF lv_request_body IS INITIAL.
      send_response(
        io_server = server
        iv_status = 400
        is_response = VALUE #(
          error_message = 'A JSON request body is required.' ) ).
      RETURN.
    ENDIF.

    IF strlen( lv_request_body ) > gc_max_request_length.
      send_response(
        io_server = server
        iv_status = 413
        is_response = VALUE #(
          error_message = 'The request body exceeds the 32 KB limit.' ) ).
      RETURN.
    ENDIF.

    DATA ls_request TYPE ty_http_request.
    /ui2/cl_json=>deserialize(
      EXPORTING
        json        = lv_request_body
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING
        data        = ls_request ).

    TRANSLATE ls_request-operation TO UPPER CASE.

    IF ls_request-operation <> 'VALIDATE_HIERARCHY'
        AND ls_request-operation <> 'REVIEW_HIERARCHY'
        AND ls_request-operation <> 'GENERATE_HIERARCHY'.
      send_response(
        io_server = server
        iv_status = 400
        is_response = VALUE #(
          error_message =
            'Operation must be VALIDATE_HIERARCHY, REVIEW_HIERARCHY, or GENERATE_HIERARCHY.' ) ).
      RETURN.
    ENDIF.

    DATA(lo_ai) = NEW zcl_product_hierarchy_ai(
      iv_destination = gc_destination
      iv_resource    = gc_resource ).

    DATA ls_ai_result TYPE zcl_product_hierarchy_ai=>ty_result.
    CASE ls_request-operation.
      WHEN 'VALIDATE_HIERARCHY'.
        ls_ai_result = lo_ai->validate_structure( ls_request-hierarchy ).
      WHEN 'REVIEW_HIERARCHY'.
        ls_ai_result = lo_ai->review_with_ai( ls_request-hierarchy ).
      WHEN 'GENERATE_HIERARCHY'.
        DATA(lv_max_depth) = ls_request-max_depth.
        IF lv_max_depth IS INITIAL.
          lv_max_depth = 3.
        ENDIF.
        ls_ai_result = lo_ai->generate_hierarchy(
          iv_product_id   = ls_request-product_id
          iv_product_name = ls_request-product_name
          iv_product_type = ls_request-product_type
          iv_max_depth    = lv_max_depth ).
    ENDCASE.

    DATA(lv_status) = ls_ai_result-status_code.
    IF lv_status IS INITIAL.
      lv_status = 500.
    ENDIF.

    send_response(
      io_server = server
      iv_status = lv_status
      is_response = VALUE #(
        success       = ls_ai_result-success
        content       = ls_ai_result-content
        error_message = ls_ai_result-error_message ) ).
  ENDMETHOD.

  METHOD send_response.
    DATA(lv_json) = /ui2/cl_json=>serialize(
      data        = is_response
      compress    = abap_true
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    io_server->response->set_status( code = iv_status reason = '' ).
    io_server->response->set_header_field(
      name  = 'Content-Type'
      value = 'application/json; charset=utf-8' ).
    io_server->response->set_header_field(
      name  = 'Cache-Control'
      value = 'no-store' ).
    io_server->response->set_cdata( lv_json ).
  ENDMETHOD.
ENDCLASS.
