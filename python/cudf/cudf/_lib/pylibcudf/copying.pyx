# Copyright (c) 2023-2024, NVIDIA CORPORATION.

from cython.operator import dereference

from libcpp.functional cimport reference_wrapper
from libcpp.memory cimport unique_ptr
from libcpp.utility cimport move
from libcpp.vector cimport vector

# TODO: We want to make cpp a more full-featured package so that we can access
# directly from that. It will make namespacing much cleaner in pylibcudf. What
# we really want here would be
# cimport libcudf... libcudf.copying.algo(...)
from cudf._lib.cpp cimport copying as cpp_copying
from cudf._lib.cpp.column.column cimport column
from cudf._lib.cpp.column.column_view cimport column_view, mutable_column_view
from cudf._lib.cpp.copying cimport mask_allocation_policy, out_of_bounds_policy
from cudf._lib.cpp.scalar.scalar cimport scalar
from cudf._lib.cpp.table.table cimport table
from cudf._lib.cpp.table.table_view cimport table_view
from cudf._lib.cpp.types cimport size_type

from cudf._lib.cpp.copying import \
    mask_allocation_policy as MaskAllocationPolicy  # no-cython-lint
from cudf._lib.cpp.copying import \
    out_of_bounds_policy as OutOfBoundsPolicy  # no-cython-lint

from .column cimport Column
from .table cimport Table

# This is a workaround for
# https://github.com/cython/cython/issues/4180
# when creating reference_wrapper[constscalar] in the constructor
ctypedef const scalar constscalar


cdef vector[reference_wrapper[const scalar]] _as_vector(list source):
    """Make a vector of reference_wrapper[const scalar] from a list of scalars."""
    cdef vector[reference_wrapper[const scalar]] c_scalars
    c_scalars.reserve(len(source))
    cdef Scalar slr
    for slr in source:
        c_scalars.push_back(
            reference_wrapper[constscalar](dereference((<Scalar?>slr).c_obj)))
    return c_scalars


cpdef Table gather(
    Table source_table,
    Column gather_map,
    out_of_bounds_policy bounds_policy
):
    """Select rows from source_table according to the provided gather_map.

    For details, see :cpp:func:`gather`.

    Parameters
    ----------
    source_table : Table
        The table object from which to pull data.
    gather_map : Column
        The list of row indices to pull out of the source table.
    bounds_policy : out_of_bounds_policy
        Controls whether out of bounds indices are checked and nullified in the
        output or if indices are assumed to be in bounds.

    Returns
    -------
    pylibcudf.Table
        The result of the gather
    """
    cdef unique_ptr[table] c_result
    with nogil:
        c_result = move(
            cpp_copying.gather(
                source_table.view(),
                gather_map.view(),
                bounds_policy
            )
        )
    return Table.from_libcudf(move(c_result))


cpdef Table scatter_table(Table source, Column scatter_map, Table target_table):
    """Scatter rows from source into target_table according to scatter_map.

    For details, see :cpp:func:`scatter`.

    Parameters
    ----------
    source : Table
        The table object from which to pull data.
    scatter_map : Column
        A mapping from rows in source to rows in target_table.
    target_table : Table
        The table object into which to scatter data.

    Returns
    -------
    pylibcudf.Table
        The result of the scatter
    """
    cdef unique_ptr[table] c_result

    with nogil:
        c_result = move(
            cpp_copying.scatter(
                source.view(),
                scatter_map.view(),
                target_table.view(),
            )
        )

    return Table.from_libcudf(move(c_result))


# TODO: Could generalize list to sequence
cpdef Table scatter_scalars(list source, Column scatter_map, Table target_table):
    """Scatter scalars from source into target_table according to scatter_map.

    For details, see :cpp:func:`scatter`.

    Parameters
    ----------
    source : List[Scalar]
        A list of scalars to scatter into target_table.
    scatter_map : Column
        A mapping from rows in source to rows in target_table.
    target_table : Table
        The table object into which to scatter data.

    Returns
    -------
    pylibcudf.Table
        The result of the scatter
    """
    cdef vector[reference_wrapper[const scalar]] source_scalars = \
        _as_vector(source)

    cdef unique_ptr[table] c_result
    with nogil:
        c_result = move(
            cpp_copying.scatter(
                source_scalars,
                scatter_map.view(),
                target_table.view(),
            )
        )

    return Table.from_libcudf(move(c_result))


cpdef object empty_column_like(Column input):
    """Create an empty column with the same type as input.

    For details, see :cpp:func:`empty_like`.

    Parameters
    ----------
    input : Column
        The column to use as a template for the output.

    Returns
    -------
    pylibcudf.Column
        An empty column with the same type as input.
    """
    cdef unique_ptr[column] c_column_result
    with nogil:
        c_column_result = move(
            cpp_copying.empty_like(
                (<Column> input).view(),
            )
        )
    return Column.from_libcudf(move(c_column_result))


cpdef object empty_table_like(Table input):
    """Create an empty table with the same type as input.

    For details, see :cpp:func:`empty_like`.

    Parameters
    ----------
    input : Table
        The table to use as a template for the output.

    Returns
    -------
    pylibcudf.Table
        An empty table with the same type as input.
    """
    cdef unique_ptr[table] c_table_result
    with nogil:
        c_table_result = move(
            cpp_copying.empty_like(
                (<Table> input).view(),
            )
        )
    return Table.from_libcudf(move(c_table_result))


cpdef Column allocate_like(
    Column input_column, mask_allocation_policy policy, size=None
):
    """Allocate a column with the same type as input_column.

    For details, see :cpp:func:`allocate_like`.

    Parameters
    ----------
    input_column : Column
        The column to use as a template for the output.
    policy : mask_allocation_policy
        Controls whether the output column has a valid mask.
    size : int, optional
        The number of elements to allocate in the output column. If not
        specified, the size of the input column is used.

    Returns
    -------
    pylibcudf.Column
        A column with the same type and size as input.
    """

    cdef unique_ptr[column] c_result
    cdef size_type c_size = size if size is not None else input_column.size()

    with nogil:
        c_result = move(
            cpp_copying.allocate_like(
                input_column.view(),
                c_size,
                policy,
            )
        )

    return Column.from_libcudf(move(c_result))


cpdef Column copy_range_in_place(
    Column input_column,
    Column target_column,
    size_type input_begin,
    size_type input_end,
    size_type target_begin,
):
    """Copy a range of elements from input_column to target_column.

    The target_column is overwritten in place.

    For details on the implementation, see :cpp:func:`copy_range_in_place`.

    Parameters
    ----------
    input_column : Column
        The column from which to copy elements.
    target_column : Column
        The column into which to copy elements.
    input_begin : int
        The index of the first element in input_column to copy.
    input_end : int
        The index of the last element in input_column to copy.
    target_begin : int
        The index of the first element in target_column to overwrite.
    """

    # Need to initialize this outside the function call so that Cython doesn't
    # try and pass a temporary that decays to an rvalue reference in where the
    # function requires an lvalue reference.
    cdef mutable_column_view target_view = target_column.mutable_view()
    with nogil:
        cpp_copying.copy_range_in_place(
            input_column.view(),
            target_view,
            input_begin,
            input_end,
            target_begin
        )


cpdef Column copy_range(
    Column input_column,
    Column target_column,
    size_type input_begin,
    size_type input_end,
    size_type target_begin,
):
    """Copy a range of elements from input_column to target_column.

    For details on the implementation, see :cpp:func:`copy_range`.

    Parameters
    ----------
    input_column : Column
        The column from which to copy elements.
    target_column : Column
        The column into which to copy elements.
    input_begin : int
        The index of the first element in input_column to copy.
    input_end : int
        The index of the last element in input_column to copy.
    target_begin : int
        The index of the first element in target_column to overwrite.

    Returns
    -------
    pylibcudf.Column
        A copy of target_column with the specified range overwritten.
    """
    cdef unique_ptr[column] c_result

    with nogil:
        c_result = move(cpp_copying.copy_range(
            input_column.view(),
            target_column.view(),
            input_begin,
            input_end,
            target_begin)
        )

    return Column.from_libcudf(move(c_result))


cpdef Column shift(Column input, size_type offset, Scalar fill_values):
    """Shift the elements of input by offset.

    For details on the implementation, see :cpp:func:`shift`.

    Parameters
    ----------
    input : Column
        The column to shift.
    offset : int
        The number of elements to shift by.
    fill_values : Scalar
        The value to use for elements that are shifted in from outside the
        bounds of the input column.

    Returns
    -------
    pylibcudf.Column
        A copy of input shifted by offset.
    """
    cdef unique_ptr[column] c_result
    with nogil:
        c_result = move(
            cpp_copying.shift(
                input.view(),
                offset,
                dereference(fill_values.c_obj)
            )
        )
    return Column.from_libcudf(move(c_result))


cpdef list column_split(Column input_column, list splits):
    """Split input_column into multiple columns.

    For details on the implementation, see :cpp:func:`split`.

    Parameters
    ----------
    input_column : Column
        The column to split.
    splits : List[int]
        The indices at which to split the column.

    Returns
    -------
    List[pylibcudf.Column]
        The result of splitting input_column.
    """
    cdef vector[size_type] c_splits
    cdef int split
    for split in splits:
        c_splits.push_back(split)

    cdef vector[column_view] c_result
    with nogil:
        c_result = move(
            cpp_copying.split(
                input_column.view(),
                c_splits
            )
        )

    cdef int i
    return [
        Column.from_column_view(c_result[i], input_column)
        for i in range(c_result.size())
    ]


cpdef list table_split(Table input_table, list splits):
    """Split input_table into multiple tables.

    For details on the implementation, see :cpp:func:`split`.

    Parameters
    ----------
    input_table : Table
        The table to split.
    splits : List[int]
        The indices at which to split the table.

    Returns
    -------
    List[pylibcudf.Table]
        The result of splitting input_table.
    """
    cdef vector[size_type] c_splits = splits
    cdef vector[table_view] c_result
    with nogil:
        c_result = move(
            cpp_copying.split(
                input_table.view(),
                c_splits
            )
        )

    cdef int i
    return [
        Table.from_table_view(c_result[i], input_table)
        for i in range(c_result.size())
    ]


cpdef list column_slice(Column input_column, list indices):
    """Slice input_column according to indices.

    For details on the implementation, see :cpp:func:`slice`.

    Parameters
    ----------
    input_column : Column
        The column to slice.
    indices : List[int]
        The indices to select from input_column.

    Returns
    -------
    List[pylibcudf.Column]
        The result of slicing input_column.
    """
    cdef vector[size_type] c_indices = indices
    cdef vector[column_view] c_result
    with nogil:
        c_result = move(
            cpp_copying.slice(
                input_column.view(),
                c_indices
            )
        )

    cdef int i
    return [
        Column.from_column_view(c_result[i], input_column)
        for i in range(c_result.size())
    ]


cpdef list table_slice(Table input_table, list indices):
    """Slice input_table according to indices.

    For details on the implementation, see :cpp:func:`slice`.

    Parameters
    ----------
    input_table : Table
        The table to slice.
    indices : List[int]
        The indices to select from input_table.

    Returns
    -------
    List[pylibcudf.Table]
        The result of slicing input_table.
    """
    cdef vector[size_type] c_indices = indices
    cdef vector[table_view] c_result
    with nogil:
        c_result = move(
            cpp_copying.slice(
                input_table.view(),
                c_indices
            )
        )

    cdef int i
    return [
        Table.from_table_view(c_result[i], input_table)
        for i in range(c_result.size())
    ]


cpdef Column copy_if_else(object lhs, object rhs, Column boolean_mask):
    """Copy elements from lhs or rhs into a new column according to boolean_mask.

    For details on the implementation, see :cpp:func:`copy_if_else`.

    Parameters
    ----------
    lhs : Column or Scalar
        The column or scalar to copy from if the corresponding element in
        boolean_mask is True.
    rhs : Column or Scalar
        The column or scalar to copy from if the corresponding element in
        boolean_mask is False.
    boolean_mask : Column
        The boolean mask to use to select elements from lhs and rhs.

    Returns
    -------
    pylibcudf.Column
        The result of copying elements from lhs and rhs according to boolean_mask.
    """
    cdef unique_ptr[column] result

    if isinstance(lhs, Column) and isinstance(rhs, Column):
        with nogil:
            result = move(
                cpp_copying.copy_if_else(
                    (<Column> lhs).view(),
                    (<Column> rhs).view(),
                    boolean_mask.view()
                )
            )
    elif isinstance(lhs, Column) and isinstance(rhs, Scalar):
        with nogil:
            result = move(
                cpp_copying.copy_if_else(
                    (<Column> lhs).view(),
                    dereference((<Scalar> rhs).c_obj),
                    boolean_mask.view()
                )
            )
    elif isinstance(lhs, Scalar) and isinstance(rhs, Column):
        with nogil:
            result = move(
                cpp_copying.copy_if_else(
                    dereference((<Scalar> lhs).c_obj),
                    (<Column> rhs).view(),
                    boolean_mask.view()
                )
            )
    elif isinstance(lhs, Scalar) and isinstance(rhs, Scalar):
        with nogil:
            result = move(
                cpp_copying.copy_if_else(
                    dereference((<Scalar> lhs).c_obj),
                    dereference((<Scalar> rhs).c_obj),
                    boolean_mask.view()
                )
            )
    else:
        raise ValueError(f"Invalid arguments {lhs} and {rhs}")

    return Column.from_libcudf(move(result))


cpdef Table boolean_mask_table_scatter(Table input, Table target, Column boolean_mask):
    """Scatter rows from input into target according to boolean_mask.

    For details on the implementation, see :cpp:func:`boolean_mask_scatter`.

    Parameters
    ----------
    input : Table
        The table object from which to pull data.
    target : Table
        The table object into which to scatter data.
    boolean_mask : Column
        A mapping from rows in input to rows in target.

    Returns
    -------
    pylibcudf.Table
        The result of the scatter
    """
    cdef unique_ptr[table] result

    with nogil:
        result = move(
            cpp_copying.boolean_mask_scatter(
                (<Table> input).view(),
                target.view(),
                boolean_mask.view()
            )
        )

    return Table.from_libcudf(move(result))


# TODO: Could generalize list to sequence
cpdef Table boolean_mask_scalars_scatter(list input, Table target, Column boolean_mask):
    """Scatter scalars from input into target according to boolean_mask.

    For details on the implementation, see :cpp:func:`boolean_mask_scatter`.

    Parameters
    ----------
    input : List[Scalar]
        A list of scalars to scatter into target.
    target : Table
        The table object into which to scatter data.
    boolean_mask : Column
        A mapping from rows in input to rows in target.

    Returns
    -------
    pylibcudf.Table
        The result of the scatter
    """
    cdef vector[reference_wrapper[const scalar]] source_scalars = _as_vector(input)

    cdef unique_ptr[table] result
    with nogil:
        result = move(
            cpp_copying.boolean_mask_scatter(
                source_scalars,
                target.view(),
                boolean_mask.view(),
            )
        )

    return Table.from_libcudf(move(result))


cpdef Scalar get_element(Column input_column, size_type index):
    """Get the element at index from input_column.

    For details on the implementation, see :cpp:func:`get_element`.

    Parameters
    ----------
    input_column : Column
        The column from which to get the element.
    index : int
        The index of the element to get.

    Returns
    -------
    pylibcudf.Scalar
        The element at index from input_column.
    """
    cdef unique_ptr[scalar] c_output
    with nogil:
        c_output = move(
            cpp_copying.get_element(input_column.view(), index)
        )

    return Scalar.from_libcudf(move(c_output))
