/*=========================================================================
 *
 *  Copyright Insight Software Consortium
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0.txt
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *=========================================================================*/
#ifndef __itkTrainSingleNodeFilter_h
#define __itkTrainSingleNodeFilter_h

#include "itkImageToImageFilter.h"
#include "itkVectorImage.h"
#include "itkImageRegionConstIterator.h"
#include "itkTransform.h"
#include "itkStateInterpolatorFunction.h"
#include "itkWeightedSinglePassMeanCovarianceUpdate.h"

namespace itk
{
template< class TInputImage, class TOutputImage = VectorImage<
    typename TInputImage::InternalPixelType, TInputImage::ImageDimension > >
class ITK_EXPORT TrainSingleNodeFilter: public ImageToImageFilter< TInputImage,
    TOutputImage >
{
public:

  typedef TrainSingleNodeFilter Self;
  typedef SmartPointer< Self > Pointer;
  typedef SmartPointer< const Self > ConstPointer;
  typedef ImageToImageFilter< TInputImage, TOutputImage > Superclass;itkNewMacro(Self)
  ;itkTypeMacro(TrainSingleNodeFilter, ImageToImageFilter)
  ;

  itkStaticConstMacro(Dimension, unsigned int, TInputImage::ImageDimension);

    typedef TInputImage InputImageType;
    typedef TOutputImage OutputImageType;
    typedef TOutputImage StateImageType;

    typedef typename InputImageType::Pointer InputImagePointer;
    typedef typename InputImageType::ConstPointer InputImageConstPointer;
    typedef typename InputImageType::RegionType InputImageRegionType;
    typedef typename InputImageType::PixelType InputPixelType;
    typedef typename InputImageType::InternalPixelType InternalPixelType;

    typedef typename OutputImageType::Pointer OutputImagePointer;
    typedef typename TOutputImage::RegionType OutputImageRegionType;
    typedef typename OutputImageType::PixelType OutputPixelType;
    typedef typename StateImageType::PixelType StateType;

    typedef Image<InternalPixelType, itkGetStaticConstMacro(Dimension) > MaskImageType;

    typedef ImageBase< itkGetStaticConstMacro(Dimension) > ImageBaseType;
    typedef typename NumericTraits<InputPixelType>::ScalarRealType ScalarRealType;
    typedef Transform<ScalarRealType, itkGetStaticConstMacro(Dimension), itkGetStaticConstMacro(Dimension) > TransformType;

    /** Image spacing,origin and direction typedef */
    typedef typename TOutputImage::SpacingType SpacingType;
    typedef typename TOutputImage::PointType OriginPointType;
    typedef typename TOutputImage::DirectionType DirectionType;
    typedef typename TOutputImage::IndexType OutputIndexType;
    typedef Size< itkGetStaticConstMacro(Dimension) > SizeType;

    typedef StateInterpolatorFunction<StateImageType, ScalarRealType> StateInterpolateType;

    virtual void SetInitialState (const StateImageType * _arg)
      {
        {
        if ( this->GetDebug() && ::itk::Object::GetGlobalWarningDisplay() )
          {
          std::ostringstream itkmsg;
          itkmsg << "Debug: In " "/home/soheil/workspace/Cascade/src/util/itkTrainSingleNodeFilter.h" ", line " << 84 << "\n"
          << this->GetNameOfClass() << " (" << this << "): " "setting " << "InitialState" " to " << _arg
          << "\n\n";
          ::itk::OutputWindowDisplayDebugText( itkmsg.str().c_str() );
          }
        };
      if ( this->m_InitialState != _arg )
        {
        this->m_InitialState = _arg;
        this->SetOutputParametersFromImage(this->m_InitialState);
        this->Modified();
        }
      }

    void SetMaskImage(const MaskImageType *maskImage)
      {
      // Process object is not const-correct so the const casting is required.
      this->SetNthInput( 1, const_cast< MaskImageType * >( maskImage ) );
      }
    const MaskImageType * GetMaskImage()
      {
      return static_cast<const MaskImageType*>(this->ProcessObject::GetInput(1));
      }

    itkGetConstObjectMacro(InitialState, StateImageType);

    itkSetConstObjectMacro(Transform, TransformType);
    itkGetConstObjectMacro(Transform, TransformType);

    itkSetMacro(Size, SizeType);
    itkGetConstReferenceMacro(Size, SizeType);

    itkSetMacro(OutputSpacing, SpacingType);
    itkGetConstReferenceMacro(OutputSpacing, SpacingType);

    itkSetMacro(OutputOrigin, OriginPointType);
    itkGetConstReferenceMacro(OutputOrigin, OriginPointType);

    itkSetMacro(OutputDirection, DirectionType);
    itkGetConstReferenceMacro(OutputDirection, DirectionType);

    itkSetMacro(OutputStartIndex, OutputIndexType);
    itkGetConstReferenceMacro(OutputStartIndex, OutputIndexType);

    /** Helper method to set the output parameters based on this image */
    void SetOutputParametersFromImage(const ImageBaseType *image);

    /** Helper method to set the output parameters based on this image */
    void SetOutputParameterFromImageWithCustomSize(const ImageBaseType *image, const SizeType& size);

    /**
     * \sa ProcessObject::GenerateOutputInformaton() */
    virtual void GenerateOutputInformation();
    /**
     * \sa ProcessObject::GenerateInputRequestedRegion() */
    virtual void GenerateInputRequestedRegion();
#ifdef ITK_USE_CONCEPT_CHECKING
    /** Begin concept checking */
    itkConceptMacro( InputCovertibleToOutputCheck,
        ( Concept::Convertible< typename InputImageType::InternalPixelType, typename OutputImageType::InternalPixelType> ) );
    /** End concept checking */
#endif
  protected:
    TrainSingleNodeFilter();
    void PrintSelf(std::ostream & os, Indent indent) const;

    virtual void GenerateData();

  private:
    typedef typename InputImageType::IndexType InputIndexType;
    typedef typename InputImageType::PointType InputPointType;
    typedef typename OutputImageType::PointType OutputPointType;
    typedef typename NumericTraits<InputPixelType>::MeasurementVectorType MeasurementVectorType;
    typedef WeightedSinglePassMeanCovarianceUpdate<StateType,MeasurementVectorType> StatisticsUpdate;

    typedef ImageRegionConstIterator< InputImageType > InputIteratorType;
    typedef ImageRegionConstIterator< MaskImageType > MaskIteratorType;
    typedef ImageRegionIterator< OutputImageType > OutputIteratorType;
    typedef ImageRegionConstIterator< OutputImageType > OutputConstIteratorType;

    typedef ContinuousIndex< double, Dimension > ContinuousIndexType;
    typedef typename ContinuousIndexType::Superclass::VectorType ContinuousVectorType;

    TrainSingleNodeFilter(const Self &); //purposely not implemented
    void operator=(const Self &);//purposely not implemented

    void UpdateOutputParameters();
    void SetInitialState();

    typename TransformType::ConstPointer m_Transform;
    typename StateImageType::ConstPointer m_InitialState;
    typename StateInterpolateType::Pointer m_StateInterpolate;

    /** Detail about the output image   */
    SizeType m_Size;      // Size of the output image
    SpacingType m_OutputSpacing;// output image spacing
    OriginPointType m_OutputOrigin;// output image origin
    DirectionType m_OutputDirection;// output image direction cosines
    OutputIndexType m_OutputStartIndex;// output image start index

    };}

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkTrainSingleNodeFilter.hxx"
#endif

#endif
