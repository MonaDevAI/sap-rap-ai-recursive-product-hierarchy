CLASS zcl_product_hierarchy_ai_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.
    CONSTANTS gc_destination TYPE rfcdest VALUE 'ZPRODUCT_HIER_AI'.
    CONSTANTS gc_resource TYPE string VALUE '/chat/completions'.
    CONSTANTS gc_url_parameter TYPE tvarvc-name VALUE 'ZPRODUCT_HIER_AI_URL'.
    CONSTANTS gc_max_request_length TYPE i VALUE 32768.

    TYPES:
      BEGIN OF ty_http_request,
        operation     TYPE string,
        hierarchy     TYPE zcl_product_hierarchy_ai=>ty_hierarchy,
        product_id    TYPE string,
        product_name  TYPE string,
        product_type  TYPE string,
        max_depth     TYPE i,
        query          TYPE string,
        level          TYPE i,
        hierarchy_type TYPE string,
        max_results    TYPE i,
        use_ai         TYPE abap_bool,
      END OF ty_http_request,
      BEGIN OF ty_http_response,
        success       TYPE abap_bool,
        content       TYPE string,
        review        TYPE zcl_product_hierarchy_ai=>ty_review,
        candidates     TYPE zcl_product_hierarchy_search=>ty_candidates,
        search_selection TYPE zcl_product_hierarchy_ai=>ty_search_selection,
        truncated     TYPE abap_bool,
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
    DATA lv_method TYPE string.
    DATA lv_request_body TYPE string.
    DATA ls_request TYPE ty_http_request.
    DATA ls_response TYPE ty_http_response.
    DATA lv_ai_url TYPE tvarvc-low.
    DATA lv_url TYPE string.
    DATA lo_ai TYPE REF TO zcl_product_hierarchy_ai.
    DATA ls_ai_result TYPE zcl_product_hierarchy_ai=>ty_result.
    DATA lv_max_depth TYPE i.
    DATA lv_status TYPE i.
    DATA lo_search TYPE REF TO zcl_product_hierarchy_search.
    DATA ls_search_result TYPE zcl_product_hierarchy_search=>ty_search_result.

    lv_method = server->request->get_header_field( '~request_method' ).

    IF lv_method <> 'POST'.
      server->response->set_header_field( name = 'Allow' value = 'POST' ).
      CLEAR ls_response.
      ls_response-error_message = 'Only POST requests are supported.'.
      send_response(
        io_server = server
        iv_status = 405
        is_response = ls_response ).
      RETURN.
    ENDIF.

    lv_request_body = server->request->get_cdata( ).
    IF lv_request_body IS INITIAL.
      CLEAR ls_response.
      ls_response-error_message = 'A JSON request body is required.'.
      send_response(
        io_server = server
        iv_status = 400
        is_response = ls_response ).
      RETURN.
    ENDIF.

    IF strlen( lv_request_body ) > gc_max_request_length.
      CLEAR ls_response.
      ls_response-error_message = 'The request body exceeds the 32 KB limit.'.
      send_response(
        io_server = server
        iv_status = 413
        is_response = ls_response ).
      RETURN.
    ENDIF.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json        = lv_request_body
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING
        data        = ls_request ).

    TRANSLATE ls_request-operation TO UPPER CASE.

    IF ls_request-operation <> 'VALIDATE_HIERARCHY'
        AND ls_request-operation <> 'REVIEW_HIERARCHY'
        AND ls_request-operation <> 'GENERATE_HIERARCHY'
        AND ls_request-operation <> 'SEARCH_HIERARCHY'.
      CLEAR ls_response.
      ls_response-error_message =
        'Unsupported hierarchy operation.'.
      send_response(
        io_server = server
        iv_status = 400
        is_response = ls_response ).
      RETURN.
    ENDIF.

    SELECT SINGLE low
      FROM tvarvc
      INTO lv_ai_url
      WHERE name = gc_url_parameter
        AND type = 'P'
        .

    lv_url = lv_ai_url.

    CREATE OBJECT lo_ai
      EXPORTING
        iv_destination = gc_destination
        iv_resource    = gc_resource
        iv_url         = lv_url.

    CASE ls_request-operation.
      WHEN 'VALIDATE_HIERARCHY'.
        ls_ai_result = lo_ai->validate_structure( ls_request-hierarchy ).
      WHEN 'REVIEW_HIERARCHY'.
        ls_ai_result = lo_ai->review_with_ai( ls_request-hierarchy ).
      WHEN 'GENERATE_HIERARCHY'.
        lv_max_depth = ls_request-max_depth.
        IF lv_max_depth IS INITIAL.
          lv_max_depth = 3.
        ENDIF.
        ls_ai_result = lo_ai->generate_hierarchy(
          iv_product_id   = ls_request-product_id
          iv_product_name = ls_request-product_name
          iv_product_type = ls_request-product_type
          iv_max_depth    = lv_max_depth ).
      WHEN 'SEARCH_HIERARCHY'.
        CREATE OBJECT lo_search.
        ls_search_result = lo_search->search(
          iv_query          = ls_request-query
          iv_level          = ls_request-level
          iv_product_type   = ls_request-product_type
          iv_hierarchy_type = ls_request-hierarchy_type
          iv_max_results    = ls_request-max_results ).

        CLEAR ls_response.
        ls_response-candidates = ls_search_result-candidates.
        ls_response-truncated = ls_search_result-truncated.

        IF ls_search_result-success <> abap_true.
          ls_response-error_message = ls_search_result-error_message.
          lv_status = ls_search_result-status_code.
        ELSEIF ls_request-use_ai = abap_true.
          ls_ai_result = lo_ai->rank_search_candidates(
            iv_query      = ls_request-query
            it_candidates = ls_search_result-candidates ).
          ls_response-success = ls_ai_result-success.
          ls_response-content = ls_ai_result-content.
          ls_response-search_selection =
            ls_ai_result-search_selection.
          ls_response-error_message = ls_ai_result-error_message.
          lv_status = ls_ai_result-status_code.
        ELSE.
          DATA(lv_candidate_count) =
            lines( ls_search_result-candidates ).
          ls_response-success = abap_true.
          ls_response-content =
            |Retrieved { lv_candidate_count } hierarchy candidates in ABAP.|.
          lv_status = 200.
        ENDIF.

        IF lv_status IS INITIAL.
          lv_status = 500.
        ENDIF.

        send_response(
          io_server = server
          iv_status = lv_status
          is_response = ls_response ).
        RETURN.
    ENDCASE.

    lv_status = ls_ai_result-status_code.
    IF lv_status IS INITIAL.
      lv_status = 500.
    ENDIF.

    CLEAR ls_response.
    ls_response-success = ls_ai_result-success.
    ls_response-content = ls_ai_result-content.
    ls_response-review = ls_ai_result-review.
    ls_response-search_selection = ls_ai_result-search_selection.
    ls_response-error_message = ls_ai_result-error_message.

    send_response(
      io_server = server
      iv_status = lv_status
      is_response = ls_response ).
  ENDMETHOD.

  METHOD send_response.
    DATA lv_json TYPE string.

    lv_json = /ui2/cl_json=>serialize(
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
