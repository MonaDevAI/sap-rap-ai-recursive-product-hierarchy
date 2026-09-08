CLASS zcl_product_hierarchy_ai DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_node,
        node_id        TYPE string,
        parent_node_id TYPE string,
        hierarchy_type TYPE string,
        hierarchy_value TYPE string,
      END OF ty_node,
      ty_nodes TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY,
      BEGIN OF ty_hierarchy,
        product_id   TYPE string,
        product_name TYPE string,
        product_type TYPE string,
        nodes        TYPE ty_nodes,
      END OF ty_hierarchy,
      BEGIN OF ty_result,
        success       TYPE abap_bool,
        content       TYPE string,
        error_message TYPE string,
        status_code   TYPE i,
      END OF ty_result.

    METHODS constructor
      IMPORTING
        iv_destination TYPE rfcdest
        iv_resource    TYPE string
        iv_model       TYPE string OPTIONAL.

    METHODS validate_structure
      IMPORTING
        is_hierarchy     TYPE ty_hierarchy
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    METHODS review_with_ai
      IMPORTING
        is_hierarchy     TYPE ty_hierarchy
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    METHODS generate_hierarchy
      IMPORTING
        iv_product_id    TYPE string
        iv_product_name  TYPE string
        iv_product_type  TYPE string
        iv_max_depth     TYPE i DEFAULT 3
      RETURNING
        VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_message,
        content TYPE string,
      END OF ty_message,
      BEGIN OF ty_choice,
        message TYPE ty_message,
      END OF ty_choice,
      ty_choices TYPE STANDARD TABLE OF ty_choice WITH EMPTY KEY,
      BEGIN OF ty_chat_response,
        choices TYPE ty_choices,
      END OF ty_chat_response,
      ty_node_ids TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    DATA mv_destination TYPE rfcdest.
    DATA mv_resource TYPE string.
    DATA mv_model TYPE string.

    METHODS call_model
      IMPORTING
        iv_system_prompt TYPE string
        iv_user_prompt   TYPE string
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    METHODS hierarchy_as_json
      IMPORTING
        is_hierarchy    TYPE ty_hierarchy
      RETURNING
        VALUE(rv_json)  TYPE string.

    METHODS escape_json
      IMPORTING
        iv_value        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.


CLASS zcl_product_hierarchy_ai IMPLEMENTATION.
  METHOD constructor.
    mv_destination = iv_destination.
    mv_resource = iv_resource.
    mv_model = iv_model.
  ENDMETHOD.

  METHOD validate_structure.
    IF is_hierarchy-product_id IS INITIAL.
      rs_result-error_message = 'Product ID is required.'.
      rs_result-status_code = 422.
      RETURN.
    ENDIF.

    IF is_hierarchy-nodes IS INITIAL.
      rs_result-error_message = 'At least one hierarchy node is required.'.
      rs_result-status_code = 422.
      RETURN.
    ENDIF.

    DATA lt_node_ids TYPE ty_node_ids.

    LOOP AT is_hierarchy-nodes INTO DATA(ls_node).
      IF ls_node-node_id IS INITIAL.
        rs_result-error_message = 'Every hierarchy node requires a node ID.'.
        rs_result-status_code = 422.
        RETURN.
      ENDIF.

      IF ls_node-hierarchy_type IS INITIAL OR ls_node-hierarchy_value IS INITIAL.
        rs_result-error_message =
          |Node { ls_node-node_id } requires hierarchy type and value.|.
        rs_result-status_code = 422.
        RETURN.
      ENDIF.

      INSERT ls_node-node_id INTO TABLE lt_node_ids.
      IF sy-subrc <> 0.
        rs_result-error_message = |Duplicate node ID { ls_node-node_id }.|.
        rs_result-status_code = 422.
        RETURN.
      ENDIF.
    ENDLOOP.

    LOOP AT is_hierarchy-nodes INTO ls_node.
      IF ls_node-parent_node_id = ls_node-node_id.
        rs_result-error_message =
          |Node { ls_node-node_id } cannot be its own parent.|.
        rs_result-status_code = 422.
        RETURN.
      ENDIF.

      IF ls_node-parent_node_id IS NOT INITIAL.
        READ TABLE lt_node_ids
          WITH TABLE KEY table_line = ls_node-parent_node_id
          TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          rs_result-error_message =
            |Parent { ls_node-parent_node_id } for node { ls_node-node_id } does not exist.|.
          rs_result-status_code = 422.
          RETURN.
        ENDIF.
      ENDIF.
    ENDLOOP.

    DATA lt_path TYPE ty_node_ids.

    LOOP AT is_hierarchy-nodes INTO ls_node.
      CLEAR lt_path.
      DATA(lv_current_node_id) = ls_node-node_id.

      WHILE lv_current_node_id IS NOT INITIAL.
        INSERT lv_current_node_id INTO TABLE lt_path.
        IF sy-subrc <> 0.
          rs_result-error_message =
            |Recursive cycle detected from node { ls_node-node_id }.|.
          rs_result-status_code = 422.
          RETURN.
        ENDIF.

        READ TABLE is_hierarchy-nodes
          WITH KEY node_id = lv_current_node_id
          INTO DATA(ls_current_node).
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.

        lv_current_node_id = ls_current_node-parent_node_id.
      ENDWHILE.
    ENDLOOP.

    rs_result-success = abap_true.
    rs_result-content = 'The recursive hierarchy passed deterministic validation.'.
    rs_result-status_code = 200.
  ENDMETHOD.

  METHOD review_with_ai.
    rs_result = validate_structure( is_hierarchy ).
    IF rs_result-success <> abap_true.
      RETURN.
    ENDIF.

    DATA(lv_system_prompt) =
      `Review a recursive SAP product hierarchy. Return concise advisory text. ` &&
      `Identify unclear labels, inconsistent hierarchy types, unusual parent-child relationships, ` &&
      `and likely missing business context. Do not approve, persist, or modify data.`.

    DATA(lv_user_prompt) = hierarchy_as_json( is_hierarchy ).

    rs_result = call_model(
      iv_system_prompt = lv_system_prompt
      iv_user_prompt   = lv_user_prompt ).
  ENDMETHOD.

  METHOD generate_hierarchy.
    IF iv_product_id IS INITIAL OR iv_product_name IS INITIAL.
      rs_result-error_message = 'Product ID and product name are required.'.
      rs_result-status_code = 422.
      RETURN.
    ENDIF.

    IF iv_max_depth < 1 OR iv_max_depth > 10.
      rs_result-error_message = 'Maximum hierarchy depth must be between 1 and 10.'.
      rs_result-status_code = 422.
      RETURN.
    ENDIF.

    DATA(lv_system_prompt) =
      `Suggest a recursive product hierarchy as JSON only. Return an object with a nodes array. ` &&
      `Each node must contain nodeId, parentNodeId, hierarchyType, and hierarchyValue. ` &&
      `Use short symbolic node IDs, use an empty parentNodeId for the root, reference only generated parents, ` &&
      `do not exceed the requested depth, and do not invent company policy or internal identifiers.`.

    DATA(lv_user_prompt) =
      |Product ID: { iv_product_id }\n| &&
      |Product name: { iv_product_name }\n| &&
      |Product type: { iv_product_type }\n| &&
      |Maximum depth: { iv_max_depth }|.

    rs_result = call_model(
      iv_system_prompt = lv_system_prompt
      iv_user_prompt   = lv_user_prompt ).
  ENDMETHOD.

  METHOD hierarchy_as_json.
    rv_json =
      '{"productId":"' && escape_json( is_hierarchy-product_id ) &&
      '","productName":"' && escape_json( is_hierarchy-product_name ) &&
      '","productType":"' && escape_json( is_hierarchy-product_type ) &&
      '","nodes":['.

    LOOP AT is_hierarchy-nodes INTO DATA(ls_node).
      IF sy-tabix > 1.
        rv_json = rv_json && ','.
      ENDIF.

      rv_json =
        rv_json &&
        '{"nodeId":"' && escape_json( ls_node-node_id ) &&
        '","parentNodeId":"' && escape_json( ls_node-parent_node_id ) &&
        '","hierarchyType":"' && escape_json( ls_node-hierarchy_type ) &&
        '","hierarchyValue":"' && escape_json( ls_node-hierarchy_value ) &&
        '"}'.
    ENDLOOP.

    rv_json = rv_json && ']}'.
  ENDMETHOD.

  METHOD call_model.
    IF mv_destination IS INITIAL OR mv_resource IS INITIAL.
      rs_result-error_message =
        'AI HTTP destination and chat-completions resource must be configured.'.
      rs_result-status_code = 500.
      RETURN.
    ENDIF.

    DATA lo_client TYPE REF TO if_http_client.

    cl_http_client=>create_by_destination(
      EXPORTING
        destination              = mv_destination
      IMPORTING
        client                   = lo_client
      EXCEPTIONS
        argument_not_found       = 1
        destination_not_found    = 2
        destination_no_authority = 3
        plugin_not_active        = 4
        internal_error           = 5
        OTHERS                   = 6 ).

    IF sy-subrc <> 0.
      rs_result-error_message =
        |Unable to create AI HTTP client for destination { mv_destination }; return code { sy-subrc }.|.
      rs_result-status_code = 502.
      RETURN.
    ENDIF.

    cl_http_utility=>set_request_uri(
      request = lo_client->request
      uri     = mv_resource ).

    lo_client->request->set_method( 'POST' ).
    lo_client->request->set_header_field(
      name  = 'Content-Type'
      value = 'application/json' ).
    lo_client->request->set_header_field(
      name  = 'Accept'
      value = 'application/json' ).

    DATA(lv_payload) =
      '{"messages":[{"role":"system","content":"' &&
      escape_json( iv_system_prompt ) &&
      '"},{"role":"user","content":"' &&
      escape_json( iv_user_prompt ) &&
      '"}],"temperature":0.1}'.

    IF mv_model IS NOT INITIAL.
      lv_payload =
        '{"model":"' && escape_json( mv_model ) &&
        '","messages":[{"role":"system","content":"' &&
        escape_json( iv_system_prompt ) &&
        '"},{"role":"user","content":"' &&
        escape_json( iv_user_prompt ) &&
        '"}],"temperature":0.1}'.
    ENDIF.

    lo_client->request->set_cdata( lv_payload ).

    lo_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      rs_result-error_message = |AI request failed to send; return code { sy-subrc }.|.
      rs_result-status_code = 502.
      lo_client->close( ).
      RETURN.
    ENDIF.

    lo_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      rs_result-error_message = |AI response failed to receive; return code { sy-subrc }.|.
      rs_result-status_code = 502.
      lo_client->close( ).
      RETURN.
    ENDIF.

    DATA lv_status_code TYPE i.
    DATA lv_reason TYPE string.

    lo_client->response->get_status(
      IMPORTING
        code   = lv_status_code
        reason = lv_reason ).

    DATA(lv_response_body) = lo_client->response->get_cdata( ).
    lo_client->close( ).

    IF lv_status_code < 200 OR lv_status_code >= 300.
      rs_result-error_message =
        |AI service returned HTTP { lv_status_code } { lv_reason }.|.
      rs_result-status_code = 502.
      RETURN.
    ENDIF.

    DATA ls_response TYPE ty_chat_response.
    /ui2/cl_json=>deserialize(
      EXPORTING
        json = lv_response_body
      CHANGING
        data = ls_response ).

    READ TABLE ls_response-choices INDEX 1 INTO DATA(ls_choice).
    IF sy-subrc <> 0 OR ls_choice-message-content IS INITIAL.
      rs_result-error_message = 'AI service response did not contain generated content.'.
      rs_result-status_code = 502.
      RETURN.
    ENDIF.

    rs_result-success = abap_true.
    rs_result-content = ls_choice-message-content.
    rs_result-status_code = 200.
  ENDMETHOD.

  METHOD escape_json.
    rv_value = iv_value.
    REPLACE ALL OCCURRENCES OF '\' IN rv_value WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_value WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_value WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_value WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv_value WITH '\t'.
  ENDMETHOD.
ENDCLASS.
