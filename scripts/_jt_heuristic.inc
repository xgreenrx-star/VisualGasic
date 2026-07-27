// ====== M6: Select Case Jump Table Heuristic ==============================
static bool _vg_jump_table_candidate(SelectStatement* sel, int64_t& out_min, int64_t& out_max, int& out_count) {
    out_min = INT64_MAX;
    out_max = INT64_MIN;
    int case_count = 0;
    for (int i = 0; i < sel->cases.size(); i++) {
        CaseBlock* cb = sel->cases[i];
        if (cb->is_else) continue;
        if (cb->values.size() != 1) return false;
        for (int r = 0; r < cb->range_ends.size(); r++)
            if (cb->range_ends[r] != nullptr) return false;
        if (cb->comparison_ops.size() > 0) return false;
        ExpressionNode* e = cb->values[0];
        if (!e || e->type != ExpressionNode::LITERAL) return false;
        LiteralNode* lit = static_cast<LiteralNode*>(e);
        if (lit->value.get_type() != Variant::INT) return false;
        int64_t v = (int64_t)lit->value;
        if (v < out_min) out_min = v;
        if (v > out_max) out_max = v;
        case_count++;
    }
    if (case_count < 8) return false;
    int64_t range = out_max - out_min + 1;
    if (range < 1 || range > 65535) return false;
    float density = (float)case_count / (float)range;
    if (density < 0.30f) return false;
    out_count = case_count;
    return true;
}
// ===========================================================================
