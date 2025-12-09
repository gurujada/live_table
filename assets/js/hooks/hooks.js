import { SortableColumn } from "./sortable_column";
import { Download } from "./download";
import { FilterToggle } from "./filter_toggle";
import live_select from "live_select";

const TableHooks = {
  SortableColumn,
  Download,
  FilterToggle,
  ...live_select,
};

export { TableHooks };

export default TableHooks;
