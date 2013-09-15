#ifndef STATEINTERPOLATORFUNCTION_HXX_
#define STATEINTERPOLATORFUNCTION_HXX_

#include "vnl/vnl_math.h"
#include "vnl/vnl_matlab_filewrite.h"
namespace itk
{

template< class TStateImage, class TCoordRep >
StateInterpolatorFunction< TStateImage, TCoordRep >::StateInterpolatorFunction()
    : m_Neighbors(1 << ImageDimension)
  {
  }
template< class TStateImage, class TCoordRep >
void StateInterpolatorFunction< TStateImage, TCoordRep >::PrintSelf(
    std::ostream & os, Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  }

template< class TStateImage, class TCoordRep >
typename StateInterpolatorFunction< TStateImage, TCoordRep >::OutputType StateInterpolatorFunction<
    TStateImage, TCoordRep >::Evaluate(const PointType & point) const
  {
  ContinuousIndexType index;

  this->GetInputImage()->TransformPhysicalPointToContinuousIndex(point, index);
  return (this->EvaluateAtContinuousIndex(index));
  }

template< class TStateImage, class TCoordRep >
typename StateInterpolatorFunction< TStateImage, TCoordRep >::OutputType StateInterpolatorFunction<
    TStateImage, TCoordRep >::EvaluateAtIndex(const IndexType & index) const
  {
  StateType output;
  PixelType input = this->GetInputImage()->GetPixel(index);

  StateTraitType::SetLength(output, StateTraitType::GetLength(input));
  StateTraitType::AssignToArray(input, output);
  return (output);
  }

template< class TStateImage, class TCoordRep >
typename StateInterpolatorFunction< TStateImage, TCoordRep >::OutputType StateInterpolatorFunction<
    TStateImage, TCoordRep >::EvaluateAtContinuousIndex(
    const ContinuousIndexType & index) const
  {
  StateType output;
  StateTraitType::SetLength(
      output, this->GetInputImage()->GetNumberOfComponentsPerPixel());
  output.Fill(0.);
  NeighborListType neighIndexes = this->GetWeightsForContinuousIndex(index);
  for (unsigned int i = 0; i < neighIndexes.size(); i++)
    {
    const StateType neighState = this->GetInputImage()->GetPixel(
        neighIndexes[i].first);
    StateUpdater::Merge(output, neighState, neighIndexes[i].second);
    }

  return (output);
  }

template< class TStateImage, class TCoordRep >
typename StateInterpolatorFunction< TStateImage, TCoordRep >::NeighborListType StateInterpolatorFunction<
    TStateImage, TCoordRep >::GetWeightsForContinuousIndex(
    const ContinuousIndexType & index) const
  {
  unsigned int dim;  // index over dimension

  /**
   * Compute base index = closet index below point
   * Compute distance from point to base index
   */
  IndexType baseIndex;
  double distance[ImageDimension];

  for (dim = 0; dim < ImageDimension; dim++)
    {
    baseIndex[dim] = Math::Floor< IndexValueType >(index[dim]);
    distance[dim] = index[dim] - static_cast< double >(baseIndex[dim]);
    }

  /**
   * Interpolated value is the weighted sum of each of the surrounding
   * neighbors. The weight for each neighbor is the fraction overlap
   * of the neighbor pixel with respect to a pixel centered on point.
   */
  ScalarRealType totalOverlap = NumericTraits< ScalarRealType >::Zero;
  NeighborListType neighbors;
  neighbors.reserve(m_Neighbors);
  for (unsigned int counter = 0; counter < m_Neighbors; counter++)
    {
    double overlap = 1.0;    // fraction overlap
    unsigned int upper = counter;    // each bit indicates upper/lower neighbour
    IndexType neighIndex;

    // get neighbor index and overlap fraction
    for (dim = 0; dim < ImageDimension; dim++)
      {
      if (upper & 1)
        {
        neighIndex[dim] = baseIndex[dim] + 1;
        // Take care of the case where the pixel is just
        // in the outer upper boundary of the image grid.
        if (neighIndex[dim] > this->m_EndIndex[dim])
          {
          neighIndex[dim] = this->m_EndIndex[dim];
          }
        overlap *= distance[dim];
        }
      else
        {
        neighIndex[dim] = baseIndex[dim];
        // Take care of the case where the pixel is just
        // in the outer lower boundary of the image grid.
        if (neighIndex[dim] < this->m_StartIndex[dim])
          {
          neighIndex[dim] = this->m_StartIndex[dim];
          }
        overlap *= 1.0 - distance[dim];
        }

      upper >>= 1;
      }

    // get neighbor value only if overlap is not zero
    if (overlap)
      {
      neighbors.push_back(std::make_pair(neighIndex, overlap));
      totalOverlap += overlap;
      }

    if (totalOverlap == 1.0)
      {
      // finished
      break;
      }
    }
  return neighbors;
  }

} // end namespace itk

#endif /* STATEINTERPOLATORFUNCTION_HXX_ */
