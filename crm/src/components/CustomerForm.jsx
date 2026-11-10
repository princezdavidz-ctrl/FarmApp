export function CustomerForm({ form, updateForm, onSubmit, onCancel, saving, staff, statuses }) {
  return (
    <section className="form-card panel-card">
      <div className="panel-heading">
        <div>
          <div className="eyebrow">
            {form.id ? "Update record" : "New relationship"}
          </div>
          <h2>{form.id ? "Edit customer" : "Add a customer"}</h2>
        </div>
        <button className="icon-button" onClick={onCancel} title="Close">
          ×
        </button>
      </div>
      <form className="customer-form" onSubmit={onSubmit}>
        <label>
          Full name
          <input
            required
            value={form.name}
            onChange={(event) => updateForm("name", event.target.value)}
            placeholder="e.g. Amara Foods"
          />
        </label>
        <div className="form-two">
          <label>
            Email
            <input
              type="email"
              value={form.email}
              onChange={(event) => updateForm("email", event.target.value)}
              placeholder="contact@company.com"
            />
          </label>
          <label>
            Phone
            <input
              value={form.phone}
              onChange={(event) => updateForm("phone", event.target.value)}
              placeholder="+254 700 000 000"
            />
          </label>
        </div>
        <div className="form-two">
          <label>
            Company
            <input
              value={form.company}
              onChange={(event) => updateForm("company", event.target.value)}
              placeholder="Business or organization"
            />
          </label>
          <label>
            Relationship
            <select
              value={form.type}
              onChange={(event) => updateForm("type", event.target.value)}
            >
              <option value="lead">Lead</option>
              <option value="buyer">Buyer</option>
              <option value="supplier">Supplier</option>
            </select>
          </label>
        </div>
        <div className="form-two">
          <label>
            Status
            <select
              value={form.status}
              onChange={(event) => updateForm("status", event.target.value)}
            >
              {statuses.slice(1).map((status) => (
                <option key={status} value={status}>
                  {status[0].toUpperCase() + status.slice(1)}
                </option>
              ))}
            </select>
          </label>
          <label>
            Assigned to
            <select value={form.assigned_user_id || ""} onChange={(event) => updateForm("assigned_user_id", event.target.value)}>
              <option value="">Unassigned</option>
              {staff.map((member) => <option key={member.id} value={member.id}>{member.name} ({member.crm_role || member.role})</option>)}
            </select>
          </label>
          <label>
            Farm ID
            <input
              value={form.farm_id}
              onChange={(event) => updateForm("farm_id", event.target.value)}
            />
          </label>
        </div>
        <label>
          Address
          <input
            value={form.address}
            onChange={(event) => updateForm("address", event.target.value)}
            placeholder="Location or postal address"
          />
        </label>
        <label>
          Notes
          <textarea
            rows="4"
            value={form.notes}
            onChange={(event) => updateForm("notes", event.target.value)}
            placeholder="Context, preferences, or next steps"
          />
        </label>
        <div className="form-actions">
          <button className="ghost-button" type="button" onClick={onCancel}>
            Cancel
          </button>
          <button className="primary-button" type="submit" disabled={saving}>
            {saving ? "Saving…" : form.id ? "Save changes" : "Create customer"}
          </button>
        </div>
      </form>
    </section>
  );
}
