CLASS zcl_product_hierarchy_search DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_candidate,
        product_id        TYPE string,
        product_name      TYPE string,
        product_type      TYPE string,
        node_id           TYPE string,
        parent_node_id    TYPE string,
        hierarchy_type    TYPE string,
        hierarchy_value   TYPE string,
        hierarchy_level   TYPE i,
        hierarchy_path    TYPE string,
      END OF ty_candidate,
      ty_candidates TYPE STANDARD TABLE OF ty_candidate WITH EMPTY KEY,
      BEGIN OF ty_search_result,
        success       TYPE abap_bool,
        candidates    TYPE ty_candidates,
        truncated     TYPE abap_bool,
        error_message TYPE string,
        status_code   TYPE i,
      END OF ty_search_result.

    METHODS search
      IMPORTING
        iv_query          TYPE string
        iv_level          TYPE i DEFAULT 0
        iv_product_type   TYPE string OPTIONAL
        iv_hierarchy_type TYPE string OPTIONAL
        iv_max_results    TYPE i DEFAULT 20
      RETURNING
        VALUE(rs_result)  TYPE ty_search_result.

  PRIVATE SECTION.
    CONSTANTS gc_max_scan TYPE i VALUE 500.
    CONSTANTS gc_max_scan_probe TYPE i VALUE 501.

    TYPES:
      BEGIN OF ty_source_node,
        product_id      TYPE string,
        product_name    TYPE string,
        product_type    TYPE string,
        node_id         TYPE string,
        parent_node_id  TYPE string,
        hierarchy_type  TYPE string,
        hierarchy_value TYPE string,
        hierarchy_path  TYPE string,
      END OF ty_source_node,
      ty_source_nodes TYPE STANDARD TABLE OF ty_source_node WITH EMPTY KEY,
      ty_node_ids TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
ENDCLASS.


CLASS zcl_product_hierarchy_search IMPLEMENTATION.
  METHOD search.
    DATA lv_query TYPE string.
    DATA lv_product_type TYPE string.
    DATA lv_hierarchy_type TYPE string.
    DATA lv_max_results TYPE i.
    DATA lt_source_nodes TYPE ty_source_nodes.

    lv_query = iv_query.
    TRANSLATE lv_query TO UPPER CASE.
    CONDENSE lv_query.

    IF lv_query IS INITIAL.
      rs_result-error_message = 'A hierarchy search query is required.'.
      rs_result-status_code = 400.
      RETURN.
    ENDIF.

    IF iv_level < 0 OR iv_level > 20.
      rs_result-error_message = 'Hierarchy level must be between 0 and 20.'.
      rs_result-status_code = 400.
      RETURN.
    ENDIF.

    lv_max_results = iv_max_results.
    IF lv_max_results IS INITIAL.
      lv_max_results = 20.
    ENDIF.

    IF lv_max_results < 1 OR lv_max_results > 50.
      rs_result-error_message = 'Maximum results must be between 1 and 50.'.
      rs_result-status_code = 400.
      RETURN.
    ENDIF.

    lv_product_type = iv_product_type.
    TRANSLATE lv_product_type TO UPPER CASE.
    CONDENSE lv_product_type.

    lv_hierarchy_type = iv_hierarchy_type.
    TRANSLATE lv_hierarchy_type TO UPPER CASE.
    CONDENSE lv_hierarchy_type.

    SELECT FROM zi_producthierarchy_i AS Hierarchy
      INNER JOIN zi_product_b AS Product
        ON Product~ProductID = Hierarchy~ProductID
      FIELDS
        Product~ProductID       AS product_id,
        Product~ProductName     AS product_name,
        Product~ProductType     AS product_type,
        Hierarchy~HierID        AS node_id,
        Hierarchy~ParentHierID  AS parent_node_id,
        Hierarchy~HierType      AS hierarchy_type,
        Hierarchy~HierValue     AS hierarchy_value,
        Hierarchy~HierarchyPath AS hierarchy_path
      INTO CORRESPONDING FIELDS OF TABLE @lt_source_nodes
      UP TO @gc_max_scan_probe ROWS.

    IF lines( lt_source_nodes ) > gc_max_scan.
      rs_result-truncated = abap_true.
      DELETE lt_source_nodes INDEX gc_max_scan_probe.
    ENDIF.

    LOOP AT lt_source_nodes INTO DATA(ls_source_node).
      DATA(lv_source_product_type) = ls_source_node-product_type.
      TRANSLATE lv_source_product_type TO UPPER CASE.
      IF lv_product_type IS NOT INITIAL
          AND lv_source_product_type <> lv_product_type.
        CONTINUE.
      ENDIF.

      DATA(lv_source_hierarchy_type) = ls_source_node-hierarchy_type.
      TRANSLATE lv_source_hierarchy_type TO UPPER CASE.
      IF lv_hierarchy_type IS NOT INITIAL
          AND lv_source_hierarchy_type <> lv_hierarchy_type.
        CONTINUE.
      ENDIF.

      DATA(lv_search_text) =
        ls_source_node-product_id && ` ` &&
        ls_source_node-product_name && ` ` &&
        ls_source_node-product_type && ` ` &&
        ls_source_node-node_id && ` ` &&
        ls_source_node-hierarchy_type && ` ` &&
        ls_source_node-hierarchy_value && ` ` &&
        ls_source_node-hierarchy_path.
      TRANSLATE lv_search_text TO UPPER CASE.
      IF lv_search_text NS lv_query.
        CONTINUE.
      ENDIF.

      DATA lv_current_node_id TYPE string.
      DATA lv_hierarchy_level TYPE i.
      DATA lv_hierarchy_path TYPE string.
      DATA lt_seen_node_ids TYPE ty_node_ids.

      lv_current_node_id = ls_source_node-node_id.
      WHILE lv_current_node_id IS NOT INITIAL.
        INSERT lv_current_node_id INTO TABLE lt_seen_node_ids.
        IF sy-subrc <> 0.
          rs_result-error_message =
            |Stored hierarchy contains a cycle at node { lv_current_node_id }.|.
          rs_result-status_code = 500.
          RETURN.
        ENDIF.

        READ TABLE lt_source_nodes
          WITH KEY product_id = ls_source_node-product_id
                   node_id = lv_current_node_id
          INTO DATA(ls_path_node).
        IF sy-subrc <> 0.
          CLEAR ls_path_node.
          SELECT SINGLE FROM zi_producthierarchy_i
            FIELDS
              ProductID      AS product_id,
              HierID         AS node_id,
              ParentHierID   AS parent_node_id,
              HierType       AS hierarchy_type,
              HierValue      AS hierarchy_value,
              HierarchyPath  AS hierarchy_path
            WHERE ProductID = @ls_source_node-product_id
              AND HierID = @lv_current_node_id
            INTO CORRESPONDING FIELDS OF @ls_path_node.
          IF sy-subrc <> 0.
            rs_result-error_message =
              |Stored hierarchy parent { lv_current_node_id } was not found.|.
            rs_result-status_code = 500.
            RETURN.
          ENDIF.
        ENDIF.

        lv_hierarchy_level = lv_hierarchy_level + 1.
        IF lv_hierarchy_path IS INITIAL.
          lv_hierarchy_path = ls_path_node-hierarchy_value.
        ELSE.
          lv_hierarchy_path =
            ls_path_node-hierarchy_value && ` > ` && lv_hierarchy_path.
        ENDIF.

        lv_current_node_id = ls_path_node-parent_node_id.
      ENDWHILE.

      IF iv_level > 0 AND lv_hierarchy_level <> iv_level.
        CONTINUE.
      ENDIF.

      IF lines( rs_result-candidates ) >= lv_max_results.
        rs_result-truncated = abap_true.
        EXIT.
      ENDIF.

      APPEND VALUE #(
        product_id      = ls_source_node-product_id
        product_name    = ls_source_node-product_name
        product_type    = ls_source_node-product_type
        node_id         = ls_source_node-node_id
        parent_node_id  = ls_source_node-parent_node_id
        hierarchy_type  = ls_source_node-hierarchy_type
        hierarchy_value = ls_source_node-hierarchy_value
        hierarchy_level = lv_hierarchy_level
        hierarchy_path  = lv_hierarchy_path )
        TO rs_result-candidates.

    ENDLOOP.

    SORT rs_result-candidates
      BY product_id hierarchy_level hierarchy_path.

    rs_result-success = abap_true.
    rs_result-status_code = 200.
  ENDMETHOD.
ENDCLASS.
