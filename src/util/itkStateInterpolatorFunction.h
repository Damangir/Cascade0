#ifndef STATEINTERPOLATORFUNCTION_H_
#define STATEINTERPOLATORFUNCTION_H_

#include "itkImageFunction.h"
#include "itkWeightedSinglePassMeanCovarianceUpdate.h"

#include <vector>
#include <utility>

namespace itk
{
template< class TStateImage, class TCoordRep = double >
class StateInterpolatorFunction: public ImageFunction< TStateImage,
    typename TStateImage::PixelType, TCoordRep >
{
public:
  /** Dimension underlying input image. */
  itkStaticConstMacro(ImageDimension, unsigned int, TStateImage::ImageDimension);

    /** Standard class typedefs. */
    typedef StateInterpolatorFunction Self;
    typedef ImageFunction<TStateImage, typename TStateImage::PixelType, TCoordRep> Superclass;

    typedef SmartPointer< Self > Pointer;
    typedef SmartPointer< const Self > ConstPointer;

    /** Method for creation through the object factory. */
    itkNewMacro(Self);
    /** Run-time type information (and related methods). */
    itkTypeMacro(StateInterpolatorFunction, ImageFunction);

    /** InputImageType typedef support. */
    typedef typename Superclass::InputImageType InputImageType;
    typedef typename InputImageType::PixelType PixelType;
    typedef typename PixelType::ValueType ValueType;
    typedef typename NumericTraits< ValueType >::RealType RealType;
    typedef typename NumericTraits< PixelType >::ScalarRealType ScalarRealType;

    /** Point typedef support. */
    typedef typename Superclass::PointType PointType;

    /** Index typedef support. */
    typedef typename Superclass::IndexType IndexType;

    /** ContinuousIndex typedef support. */
    typedef typename Superclass::ContinuousIndexType ContinuousIndexType;

    /** Output type is RealType of TStateImage::PixelType. */
    typedef typename Superclass::OutputType OutputType;

    /** CoordRep typedef support. */
    typedef TCoordRep CoordRepType;

    typedef std::pair<IndexType, ScalarRealType> NeighborType;
    typedef std::vector<NeighborType> NeighborListType;

    /** Trait for the State. */
    typedef typename TStateImage::PixelType StateType;
    typedef NumericTraits<StateType> StateTraitType;
    typedef WeightedSinglePassMeanCovarianceUpdate<StateType> StateUpdater;
    /** No bounds checking is done. */
    virtual OutputType Evaluate(const PointType & point) const;

    /** No bounds checking is done. */
    virtual OutputType EvaluateAtIndex(const IndexType & index) const;

    /** No bounds checking is done. */
    virtual OutputType EvaluateAtContinuousIndex(const ContinuousIndexType & index) const;

    NeighborListType GetWeightsForContinuousIndex(const ContinuousIndexType & index) const;

  protected:
    StateInterpolatorFunction();
    void PrintSelf(std::ostream & os, Indent indent) const;
  private:
    StateInterpolatorFunction(const Self &); //purposely not implemented
    void operator=(const Self &);//purposely not implemented
    const unsigned int m_Neighbors;
    };} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkStateInterpolatorFunction.hxx"
#endif
#endif /* STATEINTERPOLATORFUNCTION_H_ */
