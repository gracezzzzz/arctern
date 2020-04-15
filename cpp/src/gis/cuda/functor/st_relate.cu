#include <src/gis/cuda/tools/relation.h>

#include "gis/cuda/common/gpu_memory.h"
#include "gis/cuda/functor/st_relate.h"
#include "gis/cuda/tools/relation.h"

namespace arctern {
namespace gis {
namespace cuda {

using ConstIter = ConstGpuContext::ConstIter;
using de9im::Matrix;

DEVICE_RUNNABLE Matrix PointRelateOp(ConstIter& left_iter, WkbTag right_tag,
                                     ConstIter& right_iter, Matrix matrix_hint) {
  (void)matrix_hint;  // ignore
  //  auto right_tag = right.get_tag(index);
  assert(right_tag.get_space_type() == WkbSpaceType::XY);
  auto left_point = left_iter.read_value<double2>();

  //  auto right_iter = right.get_iter(index);
  Matrix result;
  switch (right_tag.get_category()) {
    case WkbCategory::kPoint: {
      auto right_point = right_iter.read_value<double2>();
      auto is_eq = IsEqual(left_point, right_point);
      result = is_eq ? Matrix("0FFFFFFF*") : Matrix("FF0FFF0F*");
      break;
    }
    case WkbCategory::kLineString: {
      auto right_size = right_iter.read_meta<int>();
      auto right_points = right_iter.read_value_ptr<double2>(right_size);
      result = PointRelateToLineString(left_point, right_size, right_points);
      break;
    }
    default: {
      assert(false);
      result = de9im::INVALID_MATRIX;
      break;
    }
  }
  return result;
}

DEVICE_RUNNABLE Matrix LineStringRelateOp(ConstIter& left_iter, WkbTag right_tag,
                                          ConstIter& right_iter, KernelBuffer& buffer) {
  assert(right_tag.get_space_type() == WkbSpaceType::XY);

  auto left_size = left_iter.read_meta<int>();
  auto left_points = left_iter.read_value_ptr<double2>(left_size);
  Matrix result;
  switch (right_tag.get_category()) {
    case WkbCategory::kPoint: {
      auto right_point = right_iter.read_value<double2>();
      auto mat = PointRelateToLineString(right_point, left_size, left_points);
      result = mat.transpose();
      break;
    }
    case WkbCategory::kLineString: {
      auto right_size = right_iter.read_meta<int>();
      auto right_points = right_iter.read_value_ptr<double2>(right_size);
      result = LineStringRelateToLineString(left_size, left_points, right_size,
                                            right_points, buffer);
      break;
    }
    default: {
      assert(false);
      result = de9im::INVALID_MATRIX;
      break;
    }
  }
  return result;
}

DEVICE_RUNNABLE Matrix RelateOp(ConstGpuContext& left, ConstGpuContext& right,
                                de9im::Matrix matrix_hint, int index) {
  auto left_tag = left.get_tag(index);
  assert(left_tag.get_space_type() == WkbSpaceType::XY);
  de9im::Matrix result;
  auto left_iter = left.get_iter(index);
  auto right_iter = right.get_iter(index);

  switch (left_tag.get_category()) {
    case WkbCategory::kPoint: {
      result = PointRelateOp(left_iter, right.get_tag(index), right_iter, matrix_hint);
      break;
    }
    case WkbCategory::kMultiLineString: {
      // TODO
      result = de9im::INVALID_MATRIX;
      break;
    }
    default: {
      result = de9im::INVALID_MATRIX;
      left_iter = left.get_iter(index + 1);
      break;
    }
  }
  assert(left_iter.values == left.get_value_ptr(index));
  assert(left_iter.metas == left.get_meta_ptr(index));
  return result;
}

__global__ void ST_RelateImpl(ConstGpuContext left, ConstGpuContext right,
                              de9im::Matrix hint_matrix, de9im::Matrix* output_matrixes) {
  auto index = threadIdx.x + blockIdx.x * blockDim.x;
  if (index < left.size) {
    output_matrixes[index] = RelateOp(left, right, hint_matrix, index);
  }
}




void ST_Relate(const GeometryVector& left_vec, const GeometryVector& right_vec,
               de9im::Matrix input_matrix, bool* host_is_matched) {
  assert(left_vec.size() == right_vec.size());
  auto size = left_vec.size();
  auto left_holder = left_vec.CreateReadGpuContext();
  auto right_holder = right_vec.CreateReadGpuContext();
//  RelateOp();

}

}  // namespace cuda
}  // namespace gis
}  // namespace arctern
