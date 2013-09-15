/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */
#ifndef __itkWeightedSinglePassMeanCovarianceUpdate_h
#define __itkWeightedSinglePassMeanCovarianceUpdate_h

#include "itkNumericTraits.h"
#include "itkVariableSizeMatrix.h"
#include "itkVariableLengthVector.h"

namespace itk
{
/*
 * Weighted covariance calculation.
 * A single pass algorithm that improves both speed and accuracy compared to
 * simple two pass algorithm. The implementation allows for merging of subset
 * statistics which can be useful for parallel calculation.
 *
 * Please note that a single instance of the class is not thread-safe. It is
 * suggested to have an instance per thread and then merge afterward.
 *
 * Implementation is based on the paper:
 * Chan, Tony F.; Golub, Gene H.; LeVeque, Randall J. (1979), “Updating Formulae
 *  and a Pairwise Algorithm for Computing Sample Variances.”, Technical Report
 *  STAN-CS-79-773, Department of Computer Science, Stanford University.
 */
template< class TState,
    class TMeasurement = typename NumericTraits< TState >::MeasurementVectorType >
class WeightedSinglePassMeanCovarianceUpdate
{
public:
  typedef TState StateType;
  typedef TMeasurement MeasurementType;

  typedef NumericTraits< StateType > StateTrait;
  typedef NumericTraits< MeasurementType > MeasurementTrait;

  typedef typename StateTrait::ScalarRealType ScalarRealType;
  /** Typedef for Mean output */
  typedef MeasurementType MeanType;
  typedef Array< typename NumericTraits< TState >::ScalarRealType > ArrayMeanType;
  /** Typedef for Covariance output */
  typedef VariableSizeMatrix< double > CovarianceType;

  static inline unsigned int GetStateDim(const MeasurementType& m)
    {
    return MeasurementToStateDim(MeasurementTrait::GetLength(m));
    }
  static inline void ResetState(StateType& state)
    {
    state.Fill(0.);
    }
  static inline bool IsValid(const StateType& state)
    {
    return state[0] > 0 ;
    }
  /*
   * Add a weighted sample and update the state
   */
  static void UpdateState(const MeasurementType & r, StateType& state,
                          double w=1.);
  /*
   * Merge the states of another estimator into this estimator.
   * Tip: Useful for multi-threading
   */
  static void Merge(StateType & state, const StateType & otherState,
                    const double w = 1);
  /*
   * Calculate the Mahalanobis distance between a measurement and a state
   */
  static ScalarRealType Distance(const StateType& state, const MeasurementType & r);
  /** Calculate bitwise orientation of a sample compare to state mean. */
  static int Orientation(const StateType& state, const MeasurementType & r);
  /**
   * Print the state.
   */
  static void PrintState(const StateType& state);
  /** Calculate the current estimate of mean vector   */
  static MeanType GetMean(const StateType& state);
  /** Calculate the current estimate of covariance matrix   */
  static CovarianceType GetCovariance(const StateType& state);
  /** Calculate ith element of the Mean vector   */
  static inline double GetMeanElement(const StateType& state, const int i)
    {
    return state[i + 1];
    }
  /*
   * Calculate i,jth element of the covariance matrix.
   * WARNING: No bound check
   */
  static inline double GetCovElement(const StateType& state, const int i,
                                     const int j)
    {
    const unsigned int D2 = StateTrait::GetLength(state);
    const unsigned int D = StateToMeasurementDim(D2);
    int stateI = 1 + D;

    int minI(i), maxI(i);
    if (i > j)
      minI = j;
    else
      maxI = j;

    if (maxI > 0)
      {
      stateI += 1 + MeasurementToStateDim(maxI - 1) - maxI + minI;
      }
    return state[stateI];
    }

  /** Calculate normalize state */
  static void MakeReady(StateType& state);
  /** Calculate state using mean and covariance  */
  static StateType GetState(const MeanType& mean, const CovarianceType& cov);
  static StateType GetState(const ArrayMeanType& mean,
                            const CovarianceType& cov)
    {
    MeanType _mean;
    NumericTraits< MeanType >::SetLength(
        _mean, NumericTraits< ArrayMeanType >::GetLength(mean));
    NumericTraits< ArrayMeanType >::AssignToArray(mean, _mean);
    return GetState(_mean, cov);
    }

  /*
   * For a measurement of D dimensional, the state should be D2 dimensional
   * where:
   * D2 = 1 + D + D(D+1)/2
   * The first element is the total weight of the state, the next D elements are
   * the estimated mean of the sample and the final D(D+1) elements are the
   * lower diagonal of the covariance matrix stored in row major order.
   */
  static inline unsigned int MeasurementToStateDim(unsigned int D)
    {
    /** This implementation is faster, maybe not a lot but feels good!  */
    static const unsigned int table[] =
      {
      1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120, 136, 153, 171
      };
    return table[D];
    //return (D * D + 3 * D + 2) / 2;
    }

  /*
   * The solution of the equation:
   * D2 = 1 + D + D(D+1)/2
   * for D
   */
  static inline unsigned int StateToMeasurementDim(unsigned int D2)
    {
    /** This implementation is faster, maybe not a lot but feels good!  */
    static unsigned int table[] =
      {
      -1, 0, -1, 1, -1, -1, 2, -1, -1, -1, 3, -1, -1, -1, -1, 4, -1, -1, -1, -1,
      -1, 5, -1, -1, -1, -1, -1, -1, 6, -1, -1, -1, -1, -1, -1, -1, 7, -1, -1,
      -1, -1, -1, -1, -1, -1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, 9, -1, -1,
      -1, -1, -1, -1, -1, -1, -1, -1, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1,
      -1, -1, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 12, -1, -1,
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 13, -1, -1, -1, -1, -1, -1,
      -1, -1, -1, -1, -1, -1, -1, -1, 14, -1, -1, -1, -1, -1, -1, -1, -1, -1,
      -1, -1, -1, -1, -1, -1, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
      -1, -1, -1, -1, -1, 16, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
      -1, -1, -1, -1, -1, 17,
      };
    return table[D2];
    //return (vcl_sqrt(9 + 8 * (D2 - 1))-3)/2;
    }
};

} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkWeightedSinglePassMeanCovarianceUpdate.hxx"
#endif
#endif
